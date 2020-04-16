import Vapor
import Fluent

final class TransactionsBusinessLogic {
    @discardableResult
    func getTransactions(user: User,
                         from: Date? = nil,
                         on req: Request) -> EventLoopFuture<[Transaction]> {
        guard let userID = user.id else {
            return req.eventLoop.makeFailedFuture(Abort(.internalServerError))
        }

        return calculateLatestTransactionDate(for: user, on: req.db)
            .flatMap { lastTransactionDate in
                let from = from ?? user.startDate
                let now = Date()

                var neededFrom = lastTransactionDate

                if from > lastTransactionDate {
                    neededFrom = from
                }

                if now < lastTransactionDate {
                    return self.fetchTransactions(for: user, from: from, to: now, on: req.db)
                } else {
                    return StarlingTransactionsController().getTransactions(user: user,
                                                                            from: neededFrom,
                                                                            on: req)
                        .flatMap { transactions in
                            transactions.forEach { $0.$user.id = userID }
                            return transactions
                                .filter {
                                    calendar.compare($0.created,
                                                     to: neededFrom,
                                                     toGranularity: .second) == .orderedDescending
                                }.map { transaction in
                                    transaction.create(on: req.db).flatMapError { _ in
                                        Transaction
                                            .find(transaction.id, on: req.db)
                                            .unwrap(or: Abort(.internalServerError))
                                            .flatMap { oldTransaction in
                                                oldTransaction.amount = transaction.amount
                                                oldTransaction.direction = transaction.direction
                                                oldTransaction.created = transaction.created
                                                oldTransaction.narrative = transaction.narrative
                                                oldTransaction.source = transaction.source
                                                return oldTransaction.update(on: req.db)
                                            }
                                    }
                                }.flatten(on: req.eventLoop)
                                .map { transactions }
                        }.flatMap { (_: [Transaction]) -> EventLoopFuture<[Transaction]> in
                            self.fetchTransactions(for: user, from: from, to: now, on: req.db)
                        }
                }
            }
    }

    func updateTransactions(user: User, on req: Request) -> EventLoopFuture<[Transaction]> {
        guard let userID = user.id else {
            return req.eventLoop.makeFailedFuture(Abort(.internalServerError))
        }

        return archiveTransactions(for: user, on: req.db)
            .flatMap { _ in self.deleteStarlingTransactions(for: user, on: req.db) }
            .flatMap { self.calculateLatestTransactionDate(for: user, on: req.db) }
            .flatMap { StarlingTransactionsController().getTransactions(user: user, from: $0, on: req) }
            .flatMap { transactions in
                transactions.forEach { $0.$user.id = userID }
                return transactions
                    .map { transaction in
                        transaction.create(on: req.db).flatMapError { _ in
                            Transaction
                                .find(transaction.id, on: req.db)
                                .unwrap(or: Abort(.internalServerError))
                                .flatMap { oldTransaction in
                                    oldTransaction.amount = transaction.amount
                                    oldTransaction.direction = transaction.direction
                                    oldTransaction.created = transaction.created
                                    oldTransaction.narrative = transaction.narrative
                                    oldTransaction.source = transaction.source
                                    return oldTransaction.update(on: req.db)
                                }
                        }
                    }.flatten(on: req.eventLoop)
                    .map { transactions }
            }
    }

    func deleteStarlingTransactions(for user: User, on conn: Database) -> EventLoopFuture<Void> {
        user.$transactions
            .query(on: conn)
            .filter(\.$source != .externalRegularOutbound)
            .filter(\.$source != .externalRegularInbound)
            .filter(\.$source != .externalOutbound)
            .filter(\.$source != .externalInbound)
            .filter(\.$source != .externalSavings)
            .filter(\.$isArchived == false)
            .delete()
    }

    func getRegularTransactions(for user: User, on conn: Database) -> EventLoopFuture<[Transaction]> {
        user.$transactions
            .query(on: conn)
            .group(.or) { group in
                group.filter(\.$source == .externalRegularOutbound)
                .filter(\.$source == .externalRegularInbound)
                .filter(\.$source == .externalSavings)
            }
            .all()
    }

    func getSavingsTransactions(for user: User, on conn: Database) -> EventLoopFuture<[Transaction]> {
        user.$transactions
            .query(on: conn)
            .filter(\.$source == .externalSavings)
            .all()
    }

    func getExternalTransactions(for user: User, on conn: Database) -> EventLoopFuture<[Transaction]> {
        user.$transactions
            .query(on: conn)
            .group(.or) { group in
                group.filter(\.$source == .externalRegularOutbound)
                .filter(\.$source == .externalRegularInbound)
                .filter(\.$source == .externalOutbound)
                .filter(\.$source == .externalInbound)
                .filter(\.$source == .externalSavings)
            }
            .all()
    }
}

// MARK: - Private methods

private extension TransactionsBusinessLogic {
    func calculateLatestTransactionDate(for user: User, on conn: Database) -> EventLoopFuture<Date> {
        user.$transactions
            .query(on: conn)
            .filter(\.$source != .externalRegularOutbound)
            .filter(\.$source != .externalRegularInbound)
            .filter(\.$source != .externalOutbound)
            .filter(\.$source != .externalInbound)
            .filter(\.$source != .externalSavings)
            .sort(\.$created, .descending)
            .first()
            .map { $0?.created ?? user.startDate }
    }

    func fetchTransactions(for user: User,
                           from: Date,
                           to: Date,
                           on conn: Database) -> EventLoopFuture<[Transaction]> {
        user.$transactions
            .query(on: conn)
            .filter(\.$created >= from)
            .filter(\.$created <= to)
            .filter(\.$source != .externalRegularOutbound)
            .filter(\.$source != .externalRegularInbound)
            .filter(\.$source != .externalSavings)
            .all()
    }

    func archiveTransactions(for user: User, on conn: Database) -> EventLoopFuture<[Transaction]> {
        user.$transactions
            .query(on: conn)
            .filter(\.$isArchived == false)
            .filter(\.$created <= Date().add(month: -2))
            .all()
            .flatMap { transactions in
                transactions.map {
                    $0.isArchived = true
                    return $0.update(on: conn)
                }.flatten(on: conn.eventLoop)
                .map { transactions }
            }
    }
}
