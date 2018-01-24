final class SpendingBusinessLogic {

    func calculateAmountSum(from transactions: [Transaction]) -> Double {
        return transactions.flatMap({ $0.amount }).reduce(0, +)
    }

}
