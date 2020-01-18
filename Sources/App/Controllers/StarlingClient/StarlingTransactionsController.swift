import Vapor

final class StarlingTransactionsController {
    private static let decoder: JSONDecoder = {
        var decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(Formatters.iso8601MillisecFormatter)
        return decoder
    }()

    func getTransactions(user: User,
                         from: Date? = nil,
                         on con: Container) throws -> EventLoopFuture<[Transaction]> {
        guard let token = user.sToken,
            let accountUid = user.accountUid,
            let categoryUid = user.categoryUid else { throw Abort(.internalServerError) }

        var parameters = StarlingParameters()

        if let from = from {
            parameters.changesSince = Formatters.iso8601MillisecFormatter.string(from: from)
        }

        return try StarlingClientController()
            .get(endpoint: .getTransactions(accountUid: accountUid, categoryUid: categoryUid),
                 token: token,
                 parameters: parameters,
                 on: con)
            .flatMap {
                try $0.content.decode(StarlingTransactionList.self,
                                      using: StarlingTransactionsController.decoder)
            }.map { $0.feedItems.compactMap { Transaction(from: $0) } }
            .catchMap { error in
                try con.make(Logger.self).error("\(error)")
                throw error
            }
    }
}
