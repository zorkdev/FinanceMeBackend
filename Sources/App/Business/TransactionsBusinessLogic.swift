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
                            transactions.forEach({ $0.userID = id })
                            return transactions
                                .filter { calendar.compare($0.created,
                                                           to: neededFrom,
                                                           toGranularity: .second) == .orderedDescending }
                                .map { $0.create(on: req) }
                                .flatten(on: req)
                        }.flatMap { (transactions: [Transaction]) -> Future<[Transaction]> in
                            return try self.fetchTransactions(for: user, from: from, to: now, on: req)
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
                return transactions.map { $0.create(on: req) }.flatten(on: req)
        }
    }

    func deleteStarlingTransactions(for user: User, on conn: DatabaseConnectable) throws -> Future<Void> {
        return try user.transactions
            .query(on: conn)
            .filter(\.source != .externalRegularOutbound)
            .filter(\.source != .externalRegularInbound)
            .filter(\.source != .externalOutbound)
            .filter(\.source != .externalInbound)
            .filter(\.isArchived == false)
            .delete()
    }

    func getRegularTransactions(for user: User, on conn: DatabaseConnectable) throws -> Future<[Transaction]> {
        return try user.transactions
            .query(on: conn)
            .group(.or) { group in
                group.filter(\.source == .externalRegularOutbound)
                .filter(\.source == .externalRegularInbound)
            }
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
            .all()
    }
}
