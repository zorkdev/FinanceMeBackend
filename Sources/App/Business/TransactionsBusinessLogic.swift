import Vapor
import FluentPostgreSQL

final class TransactionsBusinessLogic {
    @discardableResult
    func getTransactions(user: User,
                         from: Date? = nil,
                         on req: Request) throws -> Future<[Transaction]> {
        guard let id = user.id else { throw Abort(.internalServerError) }

        return try calculateLatestTransactionDate(for: user, on: req)
            .flatMap { lastTransactionDate in
                let from = from ?? user.startDate
                let now = Date()

                var neededFrom = lastTransactionDate

                if from > lastTransactionDate {
                    neededFrom = from
                }

                if now < lastTransactionDate {
                    return try self.fetchTransactions(for: user, from: from, to: now, on: req)
                } else {
                    return try StarlingTransactionsController().getTransactions(user: user,
                                                                                from: neededFrom,
                                                                                on: req)
                        .flatMap { transactions in
                            transactions.forEach { $0.userID = id }
                            return transactions
                                .filter {
                                    calendar.compare($0.created,
                                                     to: neededFrom,
                                                     toGranularity: .second) == .orderedDescending
                                }.map { transaction in
                                    transaction.create(on: req).catchFlatMap { _ in transaction.update(on: req) }
                                }.flatten(on: req)
                        }.flatMap { (_: [Transaction]) -> Future<[Transaction]> in
                            try self.fetchTransactions(for: user, from: from, to: now, on: req)
                        }
                }
            }
    }

    func updateTransactions(user: User, on req: Request) throws -> Future<[Transaction]> {
        guard let id = user.id else { throw Abort(.internalServerError) }

        return try deleteStarlingTransactions(for: user, on: req)
            .flatMap { try self.calculateLatestTransactionDate(for: user, on: req) }
            .flatMap { try StarlingTransactionsController().getTransactions(user: user, from: $0, on: req) }
            .flatMap { transactions in
                transactions.forEach { $0.userID = id }
                return transactions
                    .map { transaction in
                        transaction.create(on: req).catchFlatMap { _ in transaction.update(on: req) }
                    }.flatten(on: req)
            }
    }

    func deleteStarlingTransactions(for user: User, on conn: DatabaseConnectable) throws -> Future<Void> {
        return try user.transactions
            .query(on: conn)
            .filter(\.source != .externalRegularOutbound)
            .filter(\.source != .externalRegularInbound)
            .filter(\.source != .externalOutbound)
            .filter(\.source != .externalInbound)
            .filter(\.source != .externalSavings)
            .filter(\.isArchived == false)
            .delete()
    }

    func getRegularTransactions(for user: User, on conn: DatabaseConnectable) throws -> Future<[Transaction]> {
        return try user.transactions
            .query(on: conn)
            .group(.or) { group in
                group.filter(\.source == .externalRegularOutbound)
                .filter(\.source == .externalRegularInbound)
                .filter(\.source == .externalSavings)
            }
            .all()
    }

    func getSavingsTransactions(for user: User, on conn: DatabaseConnectable) throws -> Future<[Transaction]> {
        return try user.transactions
            .query(on: conn)
            .filter(\.source == .externalSavings)
            .all()
    }

    func getExternalTransactions(for user: User, on conn: DatabaseConnectable) throws -> Future<[Transaction]> {
        return try user.transactions
            .query(on: conn)
            .group(.or) { group in
                group.filter(\.source == .externalRegularOutbound)
                .filter(\.source == .externalRegularInbound)
                .filter(\.source == .externalOutbound)
                .filter(\.source == .externalInbound)
                .filter(\.source == .externalSavings)
            }
            .all()
    }
}

// MARK: - Private methods

private extension TransactionsBusinessLogic {
    func calculateLatestTransactionDate(for user: User, on conn: DatabaseConnectable) throws -> Future<Date> {
        return try user.transactions
            .query(on: conn)
            .filter(\.source != .externalRegularOutbound)
            .filter(\.source != .externalRegularInbound)
            .filter(\.source != .externalOutbound)
            .filter(\.source != .externalInbound)
            .filter(\.source != .externalSavings)
            .sort(\.created, .descending)
            .first()
            .map { $0?.created ?? user.startDate }
    }

    func fetchTransactions(for user: User,
                           from: Date,
                           to: Date,
                           on conn: DatabaseConnectable) throws -> Future<[Transaction]> {
        return try user.transactions
            .query(on: conn)
            .filter(\.created >= from)
            .filter(\.created <= to)
            .filter(\.source != .externalRegularOutbound)
            .filter(\.source != .externalRegularInbound)
            .filter(\.source != .externalSavings)
            .all()
    }
}
