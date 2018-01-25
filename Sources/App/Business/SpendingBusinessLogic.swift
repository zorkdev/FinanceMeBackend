import Vapor

final class SpendingBusinessLogic {

    private let starlingTransactionsController = StarlingTransactionsController()

    func calculateCurrentBalance(for user: User) throws -> Double {
        let now = Date()
        let monthModifier = now.day < user.payday ? 1 : 0
        let from = now.add(month: -1 + monthModifier).set(day: user.payday).startOfDay
        let to = now.add(month: monthModifier).set(day: user.payday).startOfDay
        let balance = try calculateBalance(for: user,
                                           from: from,
                                           to: to)

        return balance + user.endOfMonthBalance
    }

    func calculateEndOfMonthBalance(for user: User) throws -> Double {
        let now = Date()
        let monthModifier = now.day < user.payday ? -1 : 0
        let from = now.add(month: -1 + monthModifier).set(day: user.payday).startOfDay
        let to = now.add(month: monthModifier).set(day: user.payday).startOfDay
        let balance = try calculateBalance(for: user,
                                           from: from,
                                           to: to)

        return balance + user.endOfMonthBalance
    }

    func calculateBalance(for user: User, from: Date, to: Date) throws -> Double {
        let starlingTransactions = try starlingTransactionsController.getTransactions(user: user,
                                                                                      from: from,
                                                                                      to: to)
        let transactions = try user.transactions.all()
        let allTransactions = starlingTransactions + transactions
        let balance = calculateAmountSum(from: allTransactions)

        return balance
    }

    func calculateAmountSum(from transactions: [Transaction]) -> Double {
        return transactions
            .filter({ $0.source != .stripeFunding })
            .flatMap({ $0.amount })
            .reduce(0, +)
    }

}
