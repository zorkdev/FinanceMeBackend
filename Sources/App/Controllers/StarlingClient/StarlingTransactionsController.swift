import Vapor

final class StarlingTransactionsController {

    private struct Constants {
        static let embeddedKey = "_embedded"
        static let transactionsKey = "transactions"
    }

    func getTransactions(user: User,
                         from: Date? = nil,
                         to: Date? = nil) throws -> [Transaction] {
        guard let token = user.sToken else { throw Abort.serverError }

        var parameters = [String: NodeRepresentable]()

        if let from = from {
            parameters[StarlingParameters.from.rawValue] = Formatters.apiDate.string(from: from)
        }

        if let to = to {
            parameters[StarlingParameters.to.rawValue] = Formatters.apiDate.string(from: to)
        }

        let response = try StarlingClientController.shared.performRequest(method: .get,
                                                                          endpoint: .getTransactions,
                                                                          token: token,
                                                                          parameters: parameters)

        guard let json = response.json,
            let halResponse = json[Constants.embeddedKey],
            let transactionsList = halResponse[Constants.transactionsKey],
            let transactionsArray = transactionsList.array else {
            throw Abort.serverError
        }

        var transactions = [Transaction]()

        for item in transactionsArray {
            let transaction = try Transaction(json: item)
            transactions.append(transaction)
        }

        return transactions
    }

}
