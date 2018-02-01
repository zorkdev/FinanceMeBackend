final class TransactionsBusinessLogic {

    private let starlingTransactionsController = StarlingTransactionsController()

    @discardableResult func getTransactions(user: User,
                                            from: Date? = nil,
                                            to: Date? = nil) throws -> [Transaction] {
        let lastTransactionDate = try calculateLatestTransactionDate(for: user)
        let from = from ?? user.startDate
        let to = to ?? Date()

        var neededFrom = lastTransactionDate

        if from > lastTransactionDate {
            neededFrom = from
        }

        if to < lastTransactionDate {
            return try fetchTransactions(for: user, from: from, to: to)
        }

        let transactions = try starlingTransactionsController.getTransactions(user: user, from: neededFrom, to: to)

        for transaction in transactions {
            guard transaction.created > neededFrom else { continue }
            transaction.userId = user.id
            try transaction.save()
        }

        return try fetchTransactions(for: user, from: from, to: to)
    }

    func getRegularTransactions(for user: User) throws -> [Transaction] {
        return try user.transactions
            .makeQuery()
            .or { group in
                try group.filter(Transaction.Constants.sourceKey,
                                 .equals,
                                 TransactionSource.externalRegularOutbound.rawValue)
                try group.filter(Transaction.Constants.sourceKey,
                                 .equals,
                                 TransactionSource.externelRegularInbound.rawValue)
            }
            .all()
    }

    func getExternalTransactions(for user: User) throws -> [Transaction] {
        return try user.transactions
            .makeQuery()
            .or { group in
                try group.filter(Transaction.Constants.sourceKey,
                                 .equals,
                                 TransactionSource.externalRegularOutbound.rawValue)
                try group.filter(Transaction.Constants.sourceKey,
                                 .equals,
                                 TransactionSource.externelRegularInbound.rawValue)
                try group.filter(Transaction.Constants.sourceKey,
                                 .equals,
                                 TransactionSource.externalOutbound.rawValue)
                try group.filter(Transaction.Constants.sourceKey,
                                 .equals,
                                 TransactionSource.externalInbound.rawValue)
            }
            .all()
    }
}

// MARK: - Private methods

extension TransactionsBusinessLogic {

    private func calculateLatestTransactionDate(for user: User) throws -> Date {
        return try user.transactions
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
                                 TransactionSource.externalOutbound.rawValue)
                try group.filter(Transaction.Constants.sourceKey,
                                 .notEquals,
                                 TransactionSource.externalInbound.rawValue)
            }
            .sort(Transaction.Constants.createdKey, .descending)
            .limit(1)
            .first()?
            .created ?? user.startDate
    }

    private func fetchTransactions(for user: User, from: Date, to: Date) throws -> [Transaction] {
        return try user.transactions
            .makeQuery()
            .and { group in
                try group.filter(Transaction.Constants.createdKey, .greaterThanOrEquals, from)
                try group.filter(Transaction.Constants.createdKey, .lessThanOrEquals, to)
                try group.filter(Transaction.Constants.sourceKey,
                                 .notEquals,
                                 TransactionSource.externalRegularOutbound.rawValue)
                try group.filter(Transaction.Constants.sourceKey,
                                 .notEquals,
                                 TransactionSource.externelRegularInbound.rawValue)
            }
            .all()
    }

}
