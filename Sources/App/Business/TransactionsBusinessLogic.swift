import Vapor
import FluentPostgreSQL

final class TransactionsBusinessLogic {

    @discardableResult
    func getTransactions(user: User,
                         from: Date? = nil,
                         to: Date? = nil,
                         on req: Request) throws -> Future<[Transaction]> {
        guard let id = user.id else { throw Abort(.internalServerError) }

        return try calculateLatestTransactionDate(for: user, on: req)
            .flatMap { lastTransactionDate in
                let from = from ?? user.startDate
                let to = to ?? Date()

                var neededFrom = lastTransactionDate

                if from > lastTransactionDate {
                    neededFrom = from
                }

                if to < lastTransactionDate {
                    return try self.fetchTransactions(for: user, from: from, to: to, on: req)
                } else {
                    return try StarlingTransactionsController().getTransactions(user: user,
                                                                                from: neededFrom,
                                                                                to: to,
                                                                                on: req)
                        .flatMap { transactions in
                            transactions.forEach({ $0.userID = id })
                            return transactions
                                .filter { $0.created > neededFrom }
                                .map { $0.save(on: req) }.flatten(on: req)
                        }.flatMap { (transactions: [Transaction]) -> Future<[Transaction]> in
                            return try self.fetchTransactions(for: user, from: from, to: to, on: req)
                    }
                }
        }
    }

    func updateTransactions(user: User, on req: Request) throws -> Future<[Transaction]> {
        guard let id = user.id else { throw Abort(.internalServerError) }

        let from = user.startDate
        let to = Date()

        return try deleteStarlingTransactions(for: user, on: req)
            .flatMap { _ in
                return try StarlingTransactionsController().getTransactions(user: user,
                                                                            from: from,
                                                                            to: to,
                                                                            on: req)
            }.flatMap { transactions in
                transactions.forEach({ $0.userID = id })
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

extension TransactionsBusinessLogic {

    private func calculateLatestTransactionDate(for user: User, on conn: DatabaseConnectable) throws -> Future<Date> {
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

    private func fetchTransactions(for user: User,
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
