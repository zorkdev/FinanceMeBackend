import Vapor

final class SpendingBusinessLogic {

    private struct Constants {
        static let travelNarrative = "TfL"
    }

    private let transactionsBusinessLogic = TransactionsBusinessLogic()

    func calculateAllowance(for user: User) throws -> Double {
        try transactionsBusinessLogic.getTransactions(user: user, from: user.startDate, to: Date())
        let spendingLimit = try calculateSpendingLimit(for: user)
        let spendingThisWeek = try calculateSpendingThisWeek(for: user)
        let remainingTravel = try calculateRemainingTravelSpending(for: user)
        let carryOver = try calculateCarryOverFromPreviousWeeks(for: user, limit: spendingLimit)
        let weeklyLimit = self.calculateWeeklyLimit(for: user, limit: spendingLimit, carryOver: carryOver)
        let remainingAllowance = weeklyLimit + spendingThisWeek + remainingTravel

        return remainingAllowance
    }

    func calculateWeeklyLimit(for user: User, limit: Double, carryOver: Double) -> Double {
        let dailyLimit = limit / Double(Date().daysInMonth)
        print("daysInMonth: \(Date().daysInMonth)")
        guard carryOver < 0 else { return dailyLimit * Double(Date.daysInWeek) }

        let now = Date()
        let nextPayday = now.next(day: user.payday, direction: .forward)
        let startOfWeek = now.startOfWeek
        let numberOfDays = Double(nextPayday.numberOfDays(from: startOfWeek))
        let newDailyLimit = dailyLimit + (carryOver / numberOfDays)
        print("numberOfDays: \(numberOfDays)")
        let newWeeklyLimit = newDailyLimit * Double(Date.daysInWeek)

        return newWeeklyLimit
    }

    func calculateSpendingThisWeek(for user: User) throws -> Double {
        let now = Date()

        let transactions = try user.transactions
            .makeQuery()
            .and { group in
                try group.filter(Transaction.Constants.createdKey, .greaterThanOrEquals, now.startOfWeek)
                try group.filter(Transaction.Constants.createdKey, .lessThanOrEquals, now)
                try group.filter(Transaction.Constants.amountKey, .lessThan, -user.largeTransaction)
            }
            .all()

        let transactionsWithoutTravel = transactions
            .filter({ !($0.narrative == Constants.travelNarrative &&
                $0.created < now.startOfDay) })

        return calculateAmountSum(from: transactionsWithoutTravel)
    }

    func calculateSpendingLimit(for user: User) throws -> Double {
        let now = Date()
        let monthModifier = now.day > user.payday ? 1 : 0
        let from = now.add(month: -1 + monthModifier).set(day: user.payday).startOfDay
        let to = now

        let regularTransactions = try transactionsBusinessLogic.getRegularTransactions(for: user)

        let largeTransactions = try user.transactions
            .makeQuery()
            .and { group in
                try group.filter(Transaction.Constants.createdKey, .greaterThanOrEquals, from)
                try group.filter(Transaction.Constants.createdKey, .lessThan, to)
                try group.filter(Transaction.Constants.amountKey, .lessThanOrEquals, -user.largeTransaction)
            }
            .all()

        let carryOver = user.endOfMonthBalance < 0 ? user.endOfMonthBalance : 0

        return calculateAmountSum(from: regularTransactions + largeTransactions) + carryOver
    }

    private func calculateCarryOverFromPreviousWeeks(for user: User, limit: Double) throws -> Double {
        let now = Date()
        let payday = now.next(day: user.payday,
                              direction: .backward)
        guard payday.isThisWeek == false else { return 0 }
        let daysSincePayday = now.numberOfDays(from: payday)

        let transactions = try user.transactions
            .makeQuery()
            .and { group in
                try group.filter(Transaction.Constants.createdKey, .greaterThanOrEquals, payday)
                try group.filter(Transaction.Constants.createdKey, .lessThan, now.startOfWeek)
            }
            .all()

        let spending = calculateAmountSum(from: transactions)
        let dailyLimit = limit / Double(Date().daysInMonth)
        print("prevDaysInMonth: \(Date().daysInMonth)")
        let carryOver = dailyLimit * Double(daysSincePayday) + spending

        return carryOver < 0 ? carryOver : 0
    }

    private func calculateRemainingTravelSpending(for user: User) throws -> Double {
        let today = Date().startOfDay
        let dayBefore = today.add(day: -1)

        let transactions = try user.transactions
            .makeQuery()
            .and { group in
                try group.filter(Transaction.Constants.narrativeKey, .equals, Constants.travelNarrative)
                try group.filter(Transaction.Constants.createdKey, .lessThan, dayBefore)
            }
            .sort(Transaction.Constants.createdKey, .ascending)
            .all()

        let firstDate = transactions.first?.created.startOfDay ?? dayBefore
        let numberOfDays = Double(dayBefore.numberOfDays(from: firstDate))
        print("travelNumberOfDays: \(numberOfDays)")

        let dailyTravelSpending = transactions
            .flatMap({ $0.amount })
            .reduce(0, +) / numberOfDays

        let remainingDays = Double(today.endOfWeek.numberOfDays(from: today))

        return remainingDays * dailyTravelSpending
    }

    func calculateCurrentBalance(for user: User) throws -> Double {
        let now = Date()
        let from = now.next(day: user.payday, direction: .backward)
        let to = now

        let balance = try calculateBalance(for: user,
                                           from: from,
                                           to: to)

        return balance + user.endOfMonthBalance
    }

    func calculateEndOfMonthBalance(for user: User) throws -> Double {
        let now = Date()
        let to = now.next(day: user.payday, direction: .backward)
        let from = to.add(month: -1)

        let balance = try calculateBalance(for: user,
                                           from: from,
                                           to: to)

        return balance + user.endOfMonthBalance
    }

    private func calculateBalance(for user: User, from: Date, to: Date) throws -> Double {
        let transactions = try transactionsBusinessLogic.getTransactions(user: user,
                                                                         from: from,
                                                                         to: to)
        let balance = calculateAmountSum(from: transactions)

        return balance
    }

    func calculateAmountSum(from transactions: [Transaction]) -> Double {
        return transactions
            .filter({ $0.source != .stripeFunding })
            .flatMap({ $0.amount })
            .reduce(0, +)
    }

}
