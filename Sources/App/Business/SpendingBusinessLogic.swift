// swiftlint:disable file_length
import Vapor
import Fluent

final class SpendingBusinessLogic {
    enum Constants {
        static let travelNarrative = "TfL"
        static let internalTransferNarrative = "INTERNAL TRANSFER"
        static let internalTransferGoalNarrative = "💸 Monthly Cash"
        static let internalSavingsGoalNarrative = "💰 Savings"
        static let internalAmexGoalNarrative = "💳 Amex"
    }

    private let transactionsBusinessLogic = TransactionsBusinessLogic()

    // swiftlint:disable:next function_body_length
    func calculateEndOfMonthBalance(for user: User, on conn: Database) -> EventLoopFuture<Void> {
        guard let id = user.id else {
            return conn.eventLoop.makeFailedFuture(Abort(.internalServerError))
        }

        return user.$endOfMonthSummaries
            .query(on: conn)
            .sort(\.$created, .descending)
            .first()
            .flatMap { lastBalance in
                let to: Date
                let from: Date

                if let lastBalance = lastBalance {
                    guard lastBalance.created != Date().next(day: user.payday, direction: .backward) else {
                        return conn.eventLoop.makeSucceededFuture(())
                    }
                    from = lastBalance.created
                    to = from.startOfDay.next(day: user.payday, direction: .forward)
                } else {
                    to = Date().startOfDay.next(day: user.payday, direction: .backward)
                    from = to.startOfDay.next(day: user.payday, direction: .backward)
                }

                return self.transactionsBusinessLogic.getRegularTransactions(for: user, on: conn)
                    .flatMap { regulars in
                        self.transactionsBusinessLogic.getSavingsTransactions(for: user, on: conn)
                            .map { (regulars, $0) }
                    }.flatMap { regularTransactions, savingsTransactions in
                        user.$transactions
                            .query(on: conn)
                            .filter(\.$source != .externalRegularOutbound)
                            .filter(\.$source != .externalRegularInbound)
                            .filter(\.$source != .externalSavings)
                            .filter(\.$source != .stripeFunding)
                            .filter(\.$source != .directDebit)
                            .filter(\.$narrative != Constants.internalTransferGoalNarrative)
                            .filter(\.$narrative != Constants.internalTransferNarrative)
                            .filter(\.$created >= from)
                            .filter(\.$created < to)
                            .all()
                            .map { $0.filter(regularTransactions: regularTransactions) }
                            .map { $0.filterGoalTransactions() }
                            .flatMap { transactions in
                                let savings = abs(self.calculateAmountSum(from: savingsTransactions))
                                var balance = self.calculateAmountSum(from: transactions + regularTransactions)

                                if let lastBalance = lastBalance,
                                    lastBalance.balance < 0 {
                                    balance += lastBalance.balance
                                }

                                let endOfMonthSummary = EndOfMonthSummary(created: to,
                                                                          balance: balance,
                                                                          savings: savings,
                                                                          userID: id)
                                return endOfMonthSummary.save(on: conn)
                            }
                    }
            }
    }

    func calculateAllowance(for user: User, on req: Request) -> EventLoopFuture<Double> {
        let spendingLimitFuture = calculateSpendingLimit(for: user, on: req.db)
        let spendingThisWeekFuture = calculateSpendingThisWeek(for: user, on: req.db)

        return [spendingLimitFuture,
                spendingThisWeekFuture]
            .flatten(on: req.eventLoop)
            .flatMap { results in
                let spendingLimit = results[0]
                let spendingThisWeek = results[1]
                let remainingTravel = self.calculateRemainingTravelSpendingThisWeek(for: user)

                return self.calculateCarryOverFromPreviousWeeks(for: user,
                                                                limit: spendingLimit,
                                                                on: req.db)
                    .map { carryOver in
                        let weeklyLimit = self.calculateWeeklyLimit(for: user,
                                                                    limit: spendingLimit,
                                                                    carryOver: carryOver)
                        let remainingAllowance = weeklyLimit + spendingThisWeek + remainingTravel

                        req.logger.info("Allowance")
                        req.logger.info("Limit: \(spendingLimit)")
                        req.logger.info("This week: \(spendingThisWeek)")
                        req.logger.info("Travel: \(remainingTravel)")
                        req.logger.info("Carry over: \(carryOver)")
                        req.logger.info("Weekly limit: \(weeklyLimit)")
                        req.logger.info("Remaining allowance: \(remainingAllowance)")

                        return remainingAllowance
                    }
            }
    }

    func calculateCurrentMonthSummary(for user: User, on req: Request) -> EventLoopFuture<CurrentMonthSummary> {
        let now = Date()
        let nextPayday = now.startOfDay.next(day: user.payday, direction: .forward)

        let spendingLimitFuture = calculateSpendingLimit(for: user, on: req.db)
        let spendingThisMonthFuture = calculateSpendingThisMonth(for: user, on: req.db)
        let spendingTotalFuture = calculateSpendingTotalThisMonth(for: user, on: req.db)

        return [spendingLimitFuture,
                spendingThisMonthFuture,
                spendingTotalFuture]
            .flatten(on: req.eventLoop)
            .map { results in
                let spendingLimit = results[0]
                let spendingThisMonth = results[1]
                let spendingTotal = results[2]
                let dailySpendingAverage = user.dailySpendingAverage
                let remainingTravel = self.calculateRemainingTravelSpendingThisMonth(for: user)

                let allowance = spendingLimit + spendingThisMonth + remainingTravel

                let remainingDays = Double(nextPayday.numberOfDays(from: now.startOfDay.add(day: 1)))
                let forecast = spendingLimit + spendingThisMonth + dailySpendingAverage * remainingDays

                req.logger.info("Monthly allowance")
                req.logger.info("Limit: \(spendingLimit)")
                req.logger.info("This month: \(spendingThisMonth)")
                req.logger.info("Travel: \(remainingTravel)")
                req.logger.info("Remaining allowance: \(allowance)")

                req.logger.info("Monthly forecast")
                req.logger.info("Daily spending: \(dailySpendingAverage)")
                req.logger.info("Forecast: \(forecast)")

                let currentmonthSummary = CurrentMonthSummary(allowance: allowance,
                                                              forecast: forecast,
                                                              spending: spendingTotal)
                return currentmonthSummary
            }
    }

    func updateDailySpendingAverage(user: User, on req: Database) -> EventLoopFuture<Void> {
        calculateDailySpendingAverage(for: user, on: req)
            .flatMap { dailySpending in
                self.calculateDailyTravelSpending(for: user, on: req).map { (dailySpending, $0) }
            }.flatMap { dailySpending, travelSpending in
                user.dailySpendingAverage = dailySpending
                user.dailyTravelSpendingAverage = travelSpending
                return user.save(on: req)
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

    func calculateSpendingThisWeek(for user: User, on conn: Database) -> EventLoopFuture<Double> {
        let now = Date().startOfDay
        let previousPayday = now.next(day: user.payday, direction: .backward)
        let startOfWeek = max(previousPayday, now.startOfWeek)

        return calculateSpending(for: user, from: startOfWeek, withTravel: false, on: conn)
    }

    func calculateSpendingThisMonth(for user: User, on conn: Database) -> EventLoopFuture<Double> {
        let from = Date().startOfDay.next(day: user.payday, direction: .backward)
        return calculateSpending(for: user, from: from, withTravel: true, on: conn)
    }

    func calculateSpending(for user: User,
                           from: Date,
                           withTravel: Bool,
                           on conn: Database) -> EventLoopFuture<Double> {
        let now = Date()

        return transactionsBusinessLogic.getRegularTransactions(for: user, on: conn)
            .flatMap { regularTransactions in
                user.$transactions
                    .query(on: conn)
                    .filter(\.$source != .externalRegularOutbound)
                    .filter(\.$source != .externalRegularInbound)
                    .filter(\.$source != .externalSavings)
                    .filter(\.$source != .stripeFunding)
                    .filter(\.$source != .directDebit)
                    .filter(\.$narrative != Constants.internalTransferGoalNarrative)
                    .filter(\.$narrative != Constants.internalTransferNarrative)
                    .filter(\.$created >= from)
                    .filter(\.$created <= now)
                    .filter(\.$amount > -user.largeTransaction)
                    .filter(\.$amount < user.largeTransaction)
                    .all()
                    .map { $0.filter(regularTransactions: regularTransactions) }
                    .map { $0.filterGoalTransactions() }
                    .map { transactions in
                        var filteredTransactions = transactions
                        if withTravel == false {
                            filteredTransactions = filteredTransactions
                                .filter {
                                    !($0.narrative == Constants.travelNarrative && $0.created > now.startOfDay)
                                }
                        }

                        return self.calculateAmountSum(from: transactions)
                    }
            }
    }

    func calculateSpendingTotalThisMonth(for user: User, on conn: Database) -> EventLoopFuture<Double> {
        let from = Date().startOfDay.next(day: user.payday, direction: .backward)

        return transactionsBusinessLogic.getRegularTransactions(for: user, on: conn)
            .flatMap { regularTransactions in
                user.$transactions
                    .query(on: conn)
                    .filter(\.$source != .externalRegularOutbound)
                    .filter(\.$source != .externalRegularInbound)
                    .filter(\.$source != .externalSavings)
                    .filter(\.$source != .stripeFunding)
                    .filter(\.$source != .directDebit)
                    .filter(\.$narrative != Constants.internalTransferGoalNarrative)
                    .filter(\.$narrative != Constants.internalTransferNarrative)
                    .filter(\.$created >= from)
                    .all()
                    .map { $0.filter(regularTransactions: regularTransactions) }
                    .map { $0.filterGoalTransactions() }
                    .map { self.calculateAmountSum(from: $0) }
            }
    }

    func calculateSpendingLimit(for user: User, on conn: Database) -> EventLoopFuture<Double> {
        let now = Date()
        let from = now.startOfDay.next(day: user.payday, direction: .backward)
        let to = now

        return transactionsBusinessLogic.getRegularTransactions(for: user, on: conn)
            .flatMap { regularTransactions in
                user.$transactions
                    .query(on: conn)
                    .filter(\.$source != .externalRegularOutbound)
                    .filter(\.$source != .externalRegularInbound)
                    .filter(\.$source != .externalSavings)
                    .filter(\.$source != .stripeFunding)
                    .filter(\.$source != .directDebit)
                    .filter(\.$narrative != Constants.internalTransferGoalNarrative)
                    .filter(\.$narrative != Constants.internalTransferNarrative)
                    .filter(\.$created >= from)
                    .filter(\.$created < to)
                    .group(.or) { group in
                        group.filter(\.$amount <= -user.largeTransaction)
                            .filter(\.$amount >= user.largeTransaction)
                    }
                    .all()
                    .map { $0.filter(regularTransactions: regularTransactions) }
                    .map { $0.filterGoalTransactions() }
                    .flatMap { largeTransactions in
                        user.$endOfMonthSummaries
                            .query(on: conn)
                            .sort(\.$created, .descending)
                            .first()
                            .map { lastBalance in
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
                                             on conn: Database) -> EventLoopFuture<Double> {
        let now = Date().startOfDay
        let startOfWeek = now.startOfWeek
        let nextPayday = now.next(day: user.payday, direction: .forward)
        let payday = now.next(day: user.payday, direction: .backward)
        guard payday < startOfWeek else { return conn.eventLoop.makeSucceededFuture(0) }
        let daysSincePayday = startOfWeek.numberOfDays(from: payday)
        let daysInMonth = nextPayday.numberOfDays(from: payday)

        return transactionsBusinessLogic.getRegularTransactions(for: user, on: conn)
            .flatMap { regularTransactions in
                user.$transactions
                    .query(on: conn)
                    .filter(\.$source != .externalRegularOutbound)
                    .filter(\.$source != .externalRegularInbound)
                    .filter(\.$source != .externalSavings)
                    .filter(\.$source != .stripeFunding)
                    .filter(\.$source != .directDebit)
                    .filter(\.$narrative != Constants.internalTransferGoalNarrative)
                    .filter(\.$narrative != Constants.internalTransferNarrative)
                    .filter(\.$amount > -user.largeTransaction)
                    .filter(\.$amount < user.largeTransaction)
                    .filter(\.$created >= payday)
                    .filter(\.$created < startOfWeek)
                    .all()
                    .map { $0.filter(regularTransactions: regularTransactions) }
                    .map { $0.filterGoalTransactions() }
                    .map { transactions in
                        let spending = self.calculateAmountSum(from: transactions)
                        let dailyLimit = limit / Double(daysInMonth)
                        let carryOver = dailyLimit * Double(daysSincePayday) + spending

                        return carryOver < 0 ? carryOver : 0
                    }
            }
    }

    func calculateDailySpendingAverage(for user: User,
                                       on conn: Database) -> EventLoopFuture<Double> {
        let today = Date().startOfDay

        return transactionsBusinessLogic.getRegularTransactions(for: user, on: conn)
            .flatMap { regularTransactions in
                user.$transactions
                    .query(on: conn)
                    .filter(\.$source != .externalRegularOutbound)
                    .filter(\.$source != .externalRegularInbound)
                    .filter(\.$source != .externalSavings)
                    .filter(\.$source != .stripeFunding)
                    .filter(\.$source != .directDebit)
                    .filter(\.$narrative != Constants.internalTransferGoalNarrative)
                    .filter(\.$narrative != Constants.internalTransferNarrative)
                    .filter(\.$created >= user.startDate)
                    .filter(\.$created < today)
                    .all()
                    .map { $0.filter(regularTransactions: regularTransactions) }
                    .map { $0.filterGoalTransactions() }
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

    func calculateDailyTravelSpending(for user: User, on conn: Database) -> EventLoopFuture<Double> {
        let today = Date().startOfDay

        return user.$transactions
            .query(on: conn)
            .filter(\.$narrative == Constants.travelNarrative)
            .filter(\.$created < today)
            .sort(\.$created, .ascending)
            .all()
            .map { transactions in
                let firstDate = transactions.first?.created.startOfDay ?? today
                let numberOfDays = Double(today.numberOfDays(from: firstDate))
                guard numberOfDays != 0 else { return 0 }
                return self.calculateAmountSum(from: transactions) / numberOfDays
            }
    }

    func calculateAmountSum(from transactions: [Transaction]) -> Double {
        transactions
            .compactMap { $0.amount }
            .reduce(0, +)
    }
}

extension Array where Element: Transaction {
    func filter(regularTransactions: [Transaction]) -> [Transaction] {
        let mappedRegularTransactions: [(String, Double?)] = regularTransactions
            .compactMap { transaction in
                guard let narrative = transaction.internalNarrative?.lowercased() else { return nil }
                return (narrative, transaction.internalAmount)
            }

        return self.filter { transaction in
            let mappedTransaction = (transaction.narrative.lowercased(), transaction.amount)
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

    func filterGoalTransactions() -> [Transaction] {
        filter {
            if $0.narrative == SpendingBusinessLogic.Constants.internalAmexGoalNarrative {
                return $0.direction == .outbound
            }
            if $0.narrative == SpendingBusinessLogic.Constants.internalSavingsGoalNarrative {
                return $0.direction == .inbound
            }
            return true
        }
    }
}
