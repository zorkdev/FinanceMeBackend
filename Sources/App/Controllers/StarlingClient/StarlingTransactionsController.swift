import Vapor

final class StarlingTransactionsController {
    private static let decoder: JSONDecoder = {
        var decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(Formatters.iso8601MillisecFormatter)
        return decoder
    }()

    func getTransactions(user: User,
                         from: Date? = nil,
                         on req: Request) -> EventLoopFuture<[Transaction]> {
        guard let token = user.sToken,
            let accountUid = user.accountUid,
            let categoryUid = user.categoryUid else {
                return req.eventLoop.makeFailedFuture(Abort(.internalServerError))
        }

        var parameters = StarlingParameters()

        if let from = from {
            parameters.changesSince = Formatters.iso8601MillisecFormatter.string(from: from)
        }

        return StarlingClientController()
            .get(endpoint: .getTransactions(accountUid: accountUid, categoryUid: categoryUid),
                 token: token,
                 parameters: parameters,
                 on: req)
            .flatMapThrowing {
                try $0.content.decode(StarlingTransactionList.self,
                                      using: StarlingTransactionsController.decoder)
            }.map { $0.feedItems.compactMap { Transaction(from: $0) } }
            .flatMapErrorThrowing { error in
                req.logger.error("\(error)")
                throw error
            }
    }
}
