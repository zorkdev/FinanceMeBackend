import Vapor

final class StarlingBalanceController {
    func getBalance(user: User,
                    on con: Container) throws -> Future<StarlingBalance> {
        guard let token = user.sToken else { throw Abort(.internalServerError) }

        return try StarlingClientController().get(endpoint: .getBalance,
                                                  token: token,
                                                  on: con)
            .flatMap { try $0.content.decode(StarlingBalance.self) }
            .catchMap { error in
                try con.make(Logger.self).error("\(error)")
                throw error
        }
    }
}
