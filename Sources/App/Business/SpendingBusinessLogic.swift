import Vapor

final class SpendingBusinessLogic {

    private struct Constants {
        static let travelNarrative = "TfL"
    }

    private let transactionsBusinessLogic = TransactionsBusinessLogic()

    func calculateEndOfMonthBalance(for user: User) throws {
        let lastBalance = try user.endOfMonthSummaries
            .makeQuery()
            .sort(EndOfMonthSummary.Constants.createdKey, .descending)
            .limit(1)
            .first()

        let to: Date
        let from: Date

        if let lastBalance = lastBalance {
            guard lastBalance.created != Date().next(day: user.payday, direction: .backward) else { return }
            from = lastBalance.created
            to = from.next(day: user.payday, direction: .forward)
        } else {
            to = Date().next(day: user.payday, direction: .backward)
            from = to.next(day: user.payday, direction: .backward)
        }

        try transactionsBusinessLogic.getTransactions(user: user, from: from, to: to)

        let transactions = try user.transactions
            .makeQuery()
            .and { group in
                try group.filter(Transaction.Constants.createdKey, .greaterThanOrEquals, from)
                try group.filter(Transaction.Constants.createdKey, .lessThan, to)
                try group.filter(Transaction.Constants.sourceKey,
                                 .notEquals,
                                 TransactionSource.externelRegularInbound.rawValue)
                try group.filter(Transaction.Constants.sourceKey,
                                 .notEquals,
                                 TransactionSource.externalRegularOutbound.rawValue)
                try group.filter(Transaction.Constants.sourceKey,
                                 .notEquals,
                                 TransactionSource.stripeFunding.rawValue)
            }
            .all()

        let regularTransactions = try transactionsBusinessLogic.getRegularTransactions(for: user)
        var balance = calculateAmountSum(from: transactions + regularTransactions)

        if let lastBalance = lastBalance,
            lastBalance.balance < 0 {
            balance += lastBalance.balance
        }

        let endOfMonthSummary = EndOfMonthSummary(created: to,
                                                  balance: balance,
                                                  user: user)
        try endOfMonthSummary.save()
    }

    func calculateAllowance(for user: User) throws -> Double {
        try transactionsBusinessLogic.getTransactions(user: user, from: user.startDate, to: Date())
        let spendingLimit = try calculateSpendingLimit(for: user)
        let spendingThisWeek = try calculateSpendingThisWeek(for: user)
        let remainingTravel = try calculateRemainingTravelSpendingThisWeek(for: user)
        let carryOver = try calculateCarryOverFromPreviousWeeks(for: user, limit: spendingLimit)
        let weeklyLimit = self.calculateWeeklyLimit(for: user, limit: spendingLimit, carryOver: carryOver)
        let remainingAllowance = weeklyLimit + spendingThisWeek + remainingTravel

        print("Allowance")
        print("Limit: \(spendingLimit)")
        print("This week: \(spendingThisWeek)")
        print("Travel: \(remainingTravel)")
        print("Carry over: \(carryOver)")
        print("Weekly limit: \(weeklyLimit)")
        print("Remaining allowance: \(remainingAllowance)")

        return remainingAllowance
    }

    func calculateCurrentMonthSummary(for user: User) throws -> CurrentMonthSummary {
        let now = Date()
        let nextPayday = now.next(day: user.payday, direction: .forward)

        try transactionsBusinessLogic.getTransactions(user: user, from: user.startDate, to: now)
        let spendingLimit = try calculateSpendingLimit(for: user)
        let spendingThisMonth = try calculateSpendingThisMonth(for: user)
        let dailySpendingAverage = try calculateDailySpendingAverage(for: user)
        let remainingTravel = try calculateRemainingTravelSpendingThisMonth(for: user)
        let allowance = spendingLimit + spendingThisMonth + remainingTravel

        let remainingDays = Double(nextPayday.numberOfDays(from: now))
        let forecast = spendingLimit + spendingThisMonth + dailySpendingAverage * remainingDays

        print("Monthly allowance")
        print("Limit: \(spendingLimit)")
        print("This month: \(spendingThisMonth)")
        print("Travel: \(remainingTravel)")
        print("Remaining allowance: \(allowance)")

        print("Monthly forecast")
        print("Daily spending: \(dailySpendingAverage)")
        print("Forecast: \(forecast)")

        let currentmonthSummary = CurrentMonthSummary(allowance: allowance,
                                                      forecast: forecast)
        return currentmonthSummary
    }

}

// MARK: - Private methods

extension SpendingBusinessLogic {

    private func calculateWeeklyLimit(for user: User, limit: Double, carryOver: Double) -> Double {
        let now = Date()
        let previousPayday = now.next(day: user.payday, direction: .backward)
        let nextPayday = now.next(day: user.payday, direction: .forward)
        let daysUntilPayday = nextPayday.numberOfDays(from: now.startOfDay)
        let remainingDays = min(Date.daysInWeek, daysUntilPayday)
        let startOfWeek = now.startOfWeek
        let daysInMonth = nextPayday.numberOfDays(from: previousPayday)
        let dailyLimit = limit / Double(daysInMonth)
        let numberOfDays = Double(nextPayday.numberOfDays(from: startOfWeek))
        guard numberOfDays != 0 else { return 0 }
        let newDailyLimit = dailyLimit + (carryOver / numberOfDays)
        let newWeeklyLimit = newDailyLimit * Double(remainingDays)

        return newWeeklyLimit
    }

    private func calculateSpendingThisWeek(for user: User) throws -> Double {
        let from = Date().startOfWeek
        let spending = try calculateSpending(for: user, from: from)

        return spending
    }

    private func calculateSpendingThisMonth(for user: User) throws -> Double {
        let from = Date().next(day: user.payday, direction: .backward)
        let spending = try calculateSpending(for: user, from: from)

        return spending
    }

    private func calculateSpending(for user: User, from: Date) throws -> Double {
        let now = Date()

        let transactions = try user.transactions
            .makeQuery()
            .and { group in
                try group.filter(Transaction.Constants.sourceKey,
                                 .notEquals,
                                 TransactionSource.externalRegularOutbound.rawValue)
                try group.filter(Transaction.Constants.sourceKey,
                                 .notEquals,
                                 TransactionSource.externelRegularInbound.rawValue)
                try group.filter(Transaction.Constants.sourceKey,
                                 .notEquals,
                                 TransactionSource.stripeFunding.rawValue)
                try group.filter(Transaction.Constants.createdKey, .greaterThanOrEquals, from)
                try group.filter(Transaction.Constants.createdKey, .lessThanOrEquals, now)
                try group.filter(Transaction.Constants.amountKey, .greaterThan, -user.largeTransaction)
                try group.filter(Transaction.Constants.amountKey, .lessThan, user.largeTransaction)
            }
            .all()

        let transactionsWithoutTravel = transactions
            .filter({ !($0.narrative == Constants.travelNarrative &&
                $0.created > now.startOfDay) })

        return calculateAmountSum(from: transactionsWithoutTravel)
    }

    private func calculateSpendingLimit(for user: User) throws -> Double {
        let now = Date()
        let from = now.next(day: user.payday, direction: .backward)
        let to = now

        let regularTransactions = try transactionsBusinessLogic.getRegularTransactions(for: user)

        let largeTransactions = try user.transactions
            .makeQuery()
            .and { group in
                try group.filter(Transaction.Constants.sourceKey,
                                 .notEquals,
                                 TransactionSource.externalRegularOutbound.rawValue)
                try group.filter(Transaction.Constants.sourceKey,
                                 .notEquals,
                                 TransactionSource.externelRegularInbound.rawValue)
                try group.filter(Transaction.Constants.sourceKey,
                                 .notEquals,
                                 TransactionSource.stripeFunding.rawValue)
                try group.filter(Transaction.Constants.createdKey, .greaterThanOrEquals, from)
                try group.filter(Transaction.Constants.createdKey, .lessThan, to)
            }.or { group in
                try group.filter(Transaction.Constants.amountKey, .lessThanOrEquals, -user.largeTransaction)
                try group.filter(Transaction.Constants.amountKey, .greaterThanOrEquals, user.largeTransaction)
            }
            .all()

        var carryOver = 0.0

        if let lastBalance = try user.endOfMonthSummaries
            .makeQuery()
            .sort(EndOfMonthSummary.Constants.createdKey, .descending)
            .limit(1)
            .first(),
            lastBalance.balance < 0 {
            carryOver = lastBalance.balance
        }

        return calculateAmountSum(from: regularTransactions + largeTransactions) + carryOver
    }

    private func calculateCarryOverFromPreviousWeeks(for user: User, limit: Double) throws -> Double {
        let now = Date()
        let startOfWeek = now.startOfWeek
        let nextPayday = now.next(day: user.payday, direction: .forward)
        let payday = now.next(day: user.payday, direction: .backward)
        guard payday.isThisWeek == false else { return 0 }
        let daysSincePayday = startOfWeek.numberOfDays(from: payday)
        let daysInMonth = nextPayday.numberOfDays(from: payday)

        let transactions = try user.transactions
            .makeQuery()
            .and { group in
                try group.filter(Transaction.Constants.sourceKey,
                                 .notEquals,
                                 TransactionSource.externalRegularOutbound.rawValue)
                try group.filter(Transaction.Constants.sourceKey,
                                 .notEquals,
                                 TransactionSource.externelRegularInbound.rawValue)
                try group.filter(Transaction.Constants.sourceKey,
                                 .notEquals,
                                 TransactionSource.stripeFunding.rawValue)
                try group.filter(Transaction.Constants.amountKey, .greaterThan, -user.largeTransaction)
                try group.filter(Transaction.Constants.amountKey, .lessThan, user.largeTransaction)
                try group.filter(Transaction.Constants.createdKey, .greaterThanOrEquals, payday)
                try group.filter(Transaction.Constants.createdKey, .lessThan, startOfWeek)
            }
            .all()

        let spending = calculateAmountSum(from: transactions)
        let dailyLimit = limit / Double(daysInMonth)
        let carryOver = dailyLimit * Double(daysSincePayday) + spending

        return carryOver < 0 ? carryOver : 0
    }

    private func calculateDailySpendingAverage(for user: User) throws -> Double {
        let transactions = try user.transactions
            .makeQuery()
            .and { group in
                try group.filter(Transaction.Constants.sourceKey,
                                 .notEquals,
                                 TransactionSource.externalRegularOutbound.rawValue)
                try group.filter(Transaction.Constants.sourceKey,
                                 .notEquals,
                                 TransactionSource.externelRegularInbound.rawValue)
                try group.filter(Transaction.Constants.sourceKey,
                                 .notEquals,
                                 TransactionSource.stripeFunding.rawValue)
                try group.filter(Transaction.Constants.createdKey, .greaterThanOrEquals, user.startDate)
            }
            .all()

        var numberOfDays = Date().numberOfDays(from: user.startDate)
        numberOfDays = numberOfDays == 0 ? 0 : numberOfDays
        let amountSum = calculateAmountSum(from: transactions)

        return amountSum / Double(numberOfDays)
    }

    private func calculateRemainingTravelSpendingThisWeek(for user: User) throws -> Double {
        let today = Date().startOfDay
        let nextPayday = today.next(day: user.payday, direction: .forward)
        let daysUntilPayday = nextPayday.numberOfDays(from: today.startOfDay)
        let daysUntilEndOfWeek = today.endOfWeek.numberOfDays(from: today)
        let remainingDays = min(daysUntilEndOfWeek, daysUntilPayday)
        let dailySpending = try calculateDailyTravelSpending(for: user)

        return Double(remainingDays) * dailySpending
    }

    private func calculateRemainingTravelSpendingThisMonth(for user: User) throws -> Double {
        let today = Date()
        let payday = today.next(day: user.payday, direction: .forward)
        let remainingDays = Double(payday.numberOfDays(from: today))
        let dailySpending = try calculateDailyTravelSpending(for: user)

        return remainingDays * dailySpending
    }

    private func calculateDailyTravelSpending(for user: User) throws -> Double {
        let today = Date().startOfDay

        let transactions = try user.transactions
            .makeQuery()
            .and { group in
                try group.filter(Transaction.Constants.narrativeKey, .equals, Constants.travelNarrative)
                try group.filter(Transaction.Constants.createdKey, .lessThan, today)
            }
            .sort(Transaction.Constants.createdKey, .ascending)
            .all()

        let firstDate = transactions.first?.created.startOfDay ?? today
        let numberOfDays = Double(today.numberOfDays(from: firstDate))
        guard numberOfDays != 0 else { return 0 }

        let dailyTravelSpending = transactions
            .flatMap({ $0.amount })
            .reduce(0, +) / numberOfDays

        return dailyTravelSpending
    }

    private func calculateAmountSum(from transactions: [Transaction]) -> Double {
        return transactions
            .flatMap({ $0.amount })
            .reduce(0, +)
    }

}
