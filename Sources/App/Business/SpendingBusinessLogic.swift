import Vapor
import FluentPostgreSQL

final class SpendingBusinessLogic {
    enum Constants {
        static let travelNarrative = "TfL"
        static let internalTransferNarrative = "INTERNAL TRANSFER"
        static let internalTransferGoalNarrative = "💸 Monthly Cash"
        static let internalAmexGoalNarrative = "💳 Amex"
    }

    private let transactionsBusinessLogic = TransactionsBusinessLogic()

    func calculateEndOfMonthBalance(for user: User, on conn: DatabaseConnectable) throws -> Future<Void> {
        guard let id = user.id else { throw Abort(.internalServerError) }

        return try user.endOfMonthSummaries
            .query(on: conn)
            .sort(\.created, .descending)
            .first()
            .flatMap { lastBalance in
                let to: Date
                let from: Date

                if let lastBalance = lastBalance {
                    guard lastBalance.created != Date().next(day: user.payday, direction: .backward) else {
                        return conn.eventLoop.newSucceededFuture(result: ())
                    }
                    from = lastBalance.created
                    to = from.startOfDay.next(day: user.payday, direction: .forward)
                } else {
                    to = Date().startOfDay.next(day: user.payday, direction: .backward)
                    from = to.startOfDay.next(day: user.payday, direction: .backward)
                }

                return try self.transactionsBusinessLogic.getRegularTransactions(for: user, on: conn)
                    .flatMap { regularTransactions in
                        return try user.transactions
                            .query(on: conn)
                            .filter(\.source != .externalRegularOutbound)
                            .filter(\.source != .externalRegularInbound)
                            .filter(\.source != .stripeFunding)
                            .filter(\.source != .directDebit)
                            .filter(\.narrative != Constants.internalTransferGoalNarrative)
                            .filter(\.narrative != Constants.internalTransferNarrative)
                            .filter(\.created >= from)
                            .filter(\.created < to)
                            .all()
                            .map { $0.filter(regularTransactions: regularTransactions) }
                            .map { $0.filterAmexTransactions() }
                            .flatMap { transactions in
                                var balance = self.calculateAmountSum(from: transactions + regularTransactions)

                                if let lastBalance = lastBalance,
                                    lastBalance.balance < 0 {
                                    balance += lastBalance.balance
                                }

                                let endOfMonthSummary = EndOfMonthSummary(created: to,
                                                                          balance: balance,
                                                                          userID: id)
                                return endOfMonthSummary.save(on: conn).transform(to: ())
                        }
                }
        }
    }

    func calculateAllowance(for user: User, on req: Request) throws -> Future<Double> {
        let spendingLimitFuture = try calculateSpendingLimit(for: user, on: req)
        let spendingThisWeekFuture = try self.calculateSpendingThisWeek(for: user, on: req)

        return [spendingLimitFuture,
                spendingThisWeekFuture]
            .flatten(on: req)
            .flatMap { results in
                let spendingLimit = results[0]
                let spendingThisWeek = results[1]
                let remainingTravel = self.calculateRemainingTravelSpendingThisWeek(for: user)

                return try self.calculateCarryOverFromPreviousWeeks(for: user,
                                                                    limit: spendingLimit,
                                                                    on: req)
                    .map { carryOver -> Double in
                        let weeklyLimit = self.calculateWeeklyLimit(for: user,
                                                                    limit: spendingLimit,
                                                                    carryOver: carryOver)
                        let remainingAllowance = weeklyLimit + spendingThisWeek + remainingTravel

                        let logger = try req.make(Logger.self)
                        logger.info("Allowance")
                        logger.info("Limit: \(spendingLimit)")
                        logger.info("This week: \(spendingThisWeek)")
                        logger.info("Travel: \(remainingTravel)")
                        logger.info("Carry over: \(carryOver)")
                        logger.info("Weekly limit: \(weeklyLimit)")
                        logger.info("Remaining allowance: \(remainingAllowance)")

                        return remainingAllowance
                }
        }
    }

    func calculateCurrentMonthSummary(for user: User, on req: Request) throws -> Future<CurrentMonthSummary> {
        let now = Date()
        let nextPayday = now.startOfDay.next(day: user.payday, direction: .forward)

        let spendingLimitFuture = try calculateSpendingLimit(for: user, on: req)
        let spendingThisMonthFuture = try calculateSpendingThisMonth(for: user, on: req)
        let spendingTotalFuture = try calculateSpendingTotalThisMonth(for: user, on: req)

        return [spendingLimitFuture,
                spendingThisMonthFuture,
                spendingTotalFuture]
            .flatten(on: req)
            .map { results in
                let spendingLimit = results[0]
                let spendingThisMonth = results[1]
                let spendingTotal = results[2]
                let dailySpendingAverage = user.dailySpendingAverage
                let remainingTravel = self.calculateRemainingTravelSpendingThisMonth(for: user)

                let allowance = spendingLimit + spendingThisMonth + remainingTravel

                let remainingDays = Double(nextPayday.numberOfDays(from: now.startOfDay.add(day: 1)))
                let forecast = spendingLimit + spendingThisMonth + dailySpendingAverage * remainingDays

                let logger = try req.make(Logger.self)
                logger.info("Monthly allowance")
                logger.info("Limit: \(spendingLimit)")
                logger.info("This month: \(spendingThisMonth)")
                logger.info("Travel: \(remainingTravel)")
                logger.info("Remaining allowance: \(allowance)")

                logger.info("Monthly forecast")
                logger.info("Daily spending: \(dailySpendingAverage)")
                logger.info("Forecast: \(forecast)")

                let currentmonthSummary = CurrentMonthSummary(allowance: allowance,
                                                              forecast: forecast,
                                                              spending: spendingTotal)
                return currentmonthSummary
        }
    }

    func updateDailySpendingAverage(user: User, on req: Request) throws -> Future<Void> {
        return try calculateDailySpendingAverage(for: user, on: req)
            .flatMap { dailySpending in
                try self.calculateDailyTravelSpending(for: user, on: req).map { (dailySpending, $0) }
            }.flatMap { dailySpending, travelSpending in
                user.dailySpendingAverage = dailySpending
                user.dailyTravelSpendingAverage = travelSpending
                return user.save(on: req).map { _ in }
            }
    }
}

// MARK: - Private methods

private extension SpendingBusinessLogic {
    func calculateWeeklyLimit(for user: User, limit: Double, carryOver: Double) -> Double {
        let now = Date().startOfDay

        let previousPayday = now.next(day: user.payday, direction: .backward)
        let nextPayday = now.next(day: user.payday, direction: .forward)

        let startOfWeek = max(previousPayday, now.startOfWeek)
        let endOfWeek = min(nextPayday, now.endOfWeek)

        let daysInWeek = endOfWeek.numberOfDays(from: startOfWeek)
        let daysInMonth = nextPayday.numberOfDays(from: previousPayday)

        let dailyLimit = limit / Double(daysInMonth)
        let numberOfDays = Double(nextPayday.numberOfDays(from: startOfWeek))

        guard numberOfDays != 0 else { return 0 }

        let newDailyLimit = dailyLimit + (carryOver / numberOfDays)
        let newWeeklyLimit = newDailyLimit * Double(daysInWeek)

        return newWeeklyLimit
    }

    func calculateSpendingThisWeek(for user: User, on conn: DatabaseConnectable) throws -> Future<Double> {
        let now = Date().startOfDay
        let previousPayday = now.next(day: user.payday, direction: .backward)
        let startOfWeek = max(previousPayday, now.startOfWeek)

        return try calculateSpending(for: user, from: startOfWeek, withTravel: false, on: conn)
    }

    func calculateSpendingThisMonth(for user: User, on conn: DatabaseConnectable) throws -> Future<Double> {
        let from = Date().startOfDay.next(day: user.payday, direction: .backward)
        return try calculateSpending(for: user, from: from, withTravel: true, on: conn)
    }

    func calculateSpending(for user: User,
                           from: Date,
                           withTravel: Bool,
                           on conn: DatabaseConnectable) throws -> Future<Double> {
        let now = Date()

        return try transactionsBusinessLogic.getRegularTransactions(for: user, on: conn)
            .flatMap { regularTransactions in
                return try user.transactions
                    .query(on: conn)
                    .filter(\.source != .externalRegularOutbound)
                    .filter(\.source != .externalRegularInbound)
                    .filter(\.source != .stripeFunding)
                    .filter(\.source != .directDebit)
                    .filter(\.narrative != Constants.internalTransferGoalNarrative)
                    .filter(\.narrative != Constants.internalTransferNarrative)
                    .filter(\.created >= from)
                    .filter(\.created <= now)
                    .filter(\.amount > -user.largeTransaction)
                    .filter(\.amount < user.largeTransaction)
                    .all()
                    .map { $0.filter(regularTransactions: regularTransactions) }
                    .map { $0.filterAmexTransactions() }
                    .map { transactions in
                        var filteredTransactions = transactions
                        if withTravel == false {
                            filteredTransactions = filteredTransactions
                                .filter({ !($0.narrative == Constants.travelNarrative &&
                                    $0.created > now.startOfDay) })
                        }

                        return self.calculateAmountSum(from: transactions)
                }
        }
    }

    func calculateSpendingTotalThisMonth(for user: User, on conn: DatabaseConnectable) throws -> Future<Double> {
        let from = Date().startOfDay.next(day: user.payday, direction: .backward)

        return try transactionsBusinessLogic.getRegularTransactions(for: user, on: conn)
            .flatMap { regularTransactions in
                return try user.transactions
                    .query(on: conn)
                    .filter(\.source != .externalRegularOutbound)
                    .filter(\.source != .externalRegularInbound)
                    .filter(\.source != .stripeFunding)
                    .filter(\.source != .directDebit)
                    .filter(\.narrative != Constants.internalTransferGoalNarrative)
                    .filter(\.narrative != Constants.internalTransferNarrative)
                    .filter(\.created >= from)
                    .all()
                    .map { $0.filter(regularTransactions: regularTransactions) }
                    .map { $0.filterAmexTransactions() }
                    .map { self.calculateAmountSum(from: $0) }
        }
    }

    func calculateSpendingLimit(for user: User, on conn: DatabaseConnectable) throws -> Future<Double> {
        let now = Date()
        let from = now.startOfDay.next(day: user.payday, direction: .backward)
        let to = now

        return try transactionsBusinessLogic.getRegularTransactions(for: user, on: conn)
            .flatMap { regularTransactions in
                return try user.transactions
                    .query(on: conn)
                    .filter(\.source != .externalRegularOutbound)
                    .filter(\.source != .externalRegularInbound)
                    .filter(\.source != .stripeFunding)
                    .filter(\.source != .directDebit)
                    .filter(\.narrative != Constants.internalTransferGoalNarrative)
                    .filter(\.narrative != Constants.internalTransferNarrative)
                    .filter(\.created >= from)
                    .filter(\.created < to)
                    .group(.or) { group in
                        group.filter(\.amount <= -user.largeTransaction)
                            .filter(\.amount >= user.largeTransaction)
                    }
                    .all()
                    .map { $0.filter(regularTransactions: regularTransactions) }
                    .map { $0.filterAmexTransactions() }
                    .flatMap { largeTransactions in
                        return try user.endOfMonthSummaries
                            .query(on: conn)
                            .sort(\.created, .descending)
                            .first().map { lastBalance in
                                var carryOver = 0.0
                                if let lastBalance = lastBalance?.balance, lastBalance < 0 {
                                    carryOver = lastBalance
                                }
                                return self.calculateAmountSum(from: regularTransactions + largeTransactions) + carryOver
                        }
                }
        }
    }

    func calculateCarryOverFromPreviousWeeks(for user: User,
                                             limit: Double,
                                             on conn: DatabaseConnectable) throws -> Future<Double> {
        let now = Date().startOfDay
        let startOfWeek = now.startOfWeek
        let nextPayday = now.next(day: user.payday, direction: .forward)
        let payday = now.next(day: user.payday, direction: .backward)
        guard payday < startOfWeek else { return conn.eventLoop.newSucceededFuture(result: 0) }
        let daysSincePayday = startOfWeek.numberOfDays(from: payday)
        let daysInMonth = nextPayday.numberOfDays(from: payday)

        return try transactionsBusinessLogic.getRegularTransactions(for: user, on: conn)
            .flatMap { regularTransactions in
                return try user.transactions
                    .query(on: conn)
                    .filter(\.source != .externalRegularOutbound)
                    .filter(\.source != .externalRegularInbound)
                    .filter(\.source != .stripeFunding)
                    .filter(\.source != .directDebit)
                    .filter(\.narrative != Constants.internalTransferGoalNarrative)
                    .filter(\.narrative != Constants.internalTransferNarrative)
                    .filter(\.amount > -user.largeTransaction)
                    .filter(\.amount < user.largeTransaction)
                    .filter(\.created >= payday)
                    .filter(\.created < startOfWeek)
                    .all()
                    .map { $0.filter(regularTransactions: regularTransactions) }
                    .map { $0.filterAmexTransactions() }
                    .map { transactions in
                        let spending = self.calculateAmountSum(from: transactions)
                        let dailyLimit = limit / Double(daysInMonth)
                        let carryOver = dailyLimit * Double(daysSincePayday) + spending

                        return carryOver < 0 ? carryOver : 0
                }
        }
    }

    func calculateDailySpendingAverage(for user: User,
                                       on conn: DatabaseConnectable) throws -> Future<Double> {
        let today = Date().startOfDay

        return try transactionsBusinessLogic.getRegularTransactions(for: user, on: conn)
            .flatMap { regularTransactions in
                return try user.transactions
                    .query(on: conn)
                    .filter(\.source != .externalRegularOutbound)
                    .filter(\.source != .externalRegularInbound)
                    .filter(\.source != .stripeFunding)
                    .filter(\.source != .directDebit)
                    .filter(\.narrative != Constants.internalTransferGoalNarrative)
                    .filter(\.narrative != Constants.internalTransferNarrative)
                    .filter(\.created >= user.startDate)
                    .filter(\.created < today)
                    .all()
                    .map { $0.filter(regularTransactions: regularTransactions) }
                    .map { $0.filterAmexTransactions() }
                    .map { transactions in
                        var numberOfDays = today.add(day: -1).numberOfDays(from: user.startDate)
                        numberOfDays = numberOfDays == 0 ? 0 : numberOfDays
                        let amountSum = self.calculateAmountSum(from: transactions)

                        return amountSum / Double(numberOfDays)
                }
        }
    }

    func calculateRemainingTravelSpendingThisWeek(for user: User) -> Double {
        let today = Date().startOfDay
        let nextPayday = today.next(day: user.payday, direction: .forward)
        let daysUntilPayday = nextPayday.numberOfDays(from: today.startOfDay)
        let daysUntilEndOfWeek = today.endOfWeek.numberOfDays(from: today)
        let remainingDays = Double(min(daysUntilEndOfWeek, daysUntilPayday))

        return user.dailyTravelSpendingAverage * remainingDays
    }

    func calculateRemainingTravelSpendingThisMonth(for user: User) -> Double {
        let today = Date().startOfDay
        let payday = today.next(day: user.payday, direction: .forward)
        let remainingDays = Double(payday.numberOfDays(from: today.add(day: 1)))

        return user.dailyTravelSpendingAverage * remainingDays
    }

    func calculateDailyTravelSpending(for user: User, on conn: DatabaseConnectable) throws -> Future<Double> {
        let today = Date().startOfDay

        return try user.transactions
            .query(on: conn)
            .filter(\.narrative == Constants.travelNarrative)
            .filter(\.created < today)
            .sort(\.created, .ascending)
            .all()
            .map { transactions in
                let firstDate = transactions.first?.created.startOfDay ?? today
                let numberOfDays = Double(today.numberOfDays(from: firstDate))
                guard numberOfDays != 0 else { return 0 }
                return self.calculateAmountSum(from: transactions) / numberOfDays
        }
    }

    func calculateAmountSum(from transactions: [Transaction]) -> Double {
        return transactions
            .compactMap({ $0.amount })
            .reduce(0, +)
    }
}

extension Array where Element: Transaction {
    func filter(regularTransactions: [Transaction]) -> [Transaction] {
        let mappedRegularTransactions: [(String, Double?)] = regularTransactions
            .compactMap { transaction in
                guard let narrative = transaction.internalNarrative else { return nil }
                return (narrative, transaction.internalAmount)
        }

        return self.filter { transaction in
            let mappedTransaction = (transaction.narrative, transaction.amount)
            return !mappedRegularTransactions
                .contains { regularTransaction in
                    if let amount = regularTransaction.1 {
                        return mappedTransaction.0 == regularTransaction.0 && mappedTransaction.1 == amount
                    } else {
                        return mappedTransaction.0 == regularTransaction.0
                    }
            }
        }
    }

    func filterAmexTransactions() -> [Transaction] {
        return filter {
            if $0.narrative == SpendingBusinessLogic.Constants.internalAmexGoalNarrative {
                return $0.direction == .outbound
            }
            return true
        }
    }
}
