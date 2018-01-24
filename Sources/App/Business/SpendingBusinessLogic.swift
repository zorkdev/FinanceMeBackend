import Vapor

final class SpendingBusinessLogic {

    private let starlingTransactionsController = StarlingTransactionsController()

    func calculateEndOfMonthBalance(for user: User) throws -> Double {
        let now = Date()
        let from = now.next(day: user.payday, direction: .backward)
        let to = now.next(day: user.payday, direction: .forward)
        let starlingTransactions = try starlingTransactionsController.getTransactions(user: user,
                                                                                      from: from,
                                                                                      to: to)
        let transactions = try user.transactions.all()
        let allTransactions = starlingTransactions + transactions
        let endOfMonthBalance = calculateAmountSum(from: allTransactions)

        return endOfMonthBalance + user.endOfMonthBalance
    }

    func calculateAmountSum(from transactions: [Transaction]) -> Double {
        return transactions
            .filter({ $0.source != .stripeFunding })
            .flatMap({ $0.amount })
            .reduce(0, +)
    }

}
