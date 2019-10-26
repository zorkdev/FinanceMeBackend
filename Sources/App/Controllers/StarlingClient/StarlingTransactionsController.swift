import Vapor

final class StarlingTransactionsController {
    private static let decoder: JSONDecoder = {
        var decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(Formatters.iso8601MillisecFormatter)
        return decoder
    }()

    func getTransactions(user: User,
                         from: Date? = nil,
                         to: Date? = nil,
                         on con: Container) throws -> Future<[Transaction]> {
        guard let token = user.sToken else { throw Abort(.internalServerError) }

        var parameters = StarlingParameters()

        if let from = from {
            parameters.from = Formatters.apiDate.string(from: from)
        }

        if let to = to {
            parameters.to = Formatters.apiDate.string(from: to)
        }

        return try StarlingClientController().get(endpoint: .getTransactions,
                                                  token: token,
                                                  parameters: parameters,
                                                  on: con)
            .flatMap { try $0.content.decode(HALResponse<TransactionList>.self,
                                             using: StarlingTransactionsController.decoder) }
            .map { $0.embedded.transactions.map { Transaction(from: $0) } }
            .catchMap { error in
                try con.make(Logger.self).error("\(error)")
                throw error
        }
    }
}
