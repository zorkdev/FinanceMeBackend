import Vapor

final class StarlingBalanceController {
    func getBalance(user: User,
                    on req: Request) -> EventLoopFuture<StarlingBalance> {
        guard let token = user.sToken,
            let accountUid = user.accountUid else {
                return req.eventLoop.makeFailedFuture(Abort(.internalServerError))
        }

        return StarlingClientController().get(endpoint: .getBalance(accountUid: accountUid),
                                              token: token,
                                              on: req)
            .flatMapThrowing { try $0.content.decode(StarlingBalance.self) }
            .flatMapErrorThrowing { error in
                req.logger.error("\(error)")
                throw error
            }
    }
}
