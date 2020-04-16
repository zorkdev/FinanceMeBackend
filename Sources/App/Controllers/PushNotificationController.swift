import Vapor

final class PushNotificationController {
    private let spendingBusinessLogic = SpendingBusinessLogic()

    func store(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let user = try req.auth.require(User.self)
        let deviceTokenRequest = try req.content.decode(DeviceTokenRequest.self)

        let token = deviceTokenRequest.deviceToken
        guard user.deviceTokens.contains(token) == false else {
            return req.eventLoop.makeSucceededFuture(.ok)
        }
        user.deviceTokens.append(token)
        return user.save(on: req.db).transform(to: .ok)
    }

    func sendNotification(user: User, on req: Request) -> EventLoopFuture<[Data]> {
        spendingBusinessLogic.calculateAllowance(for: user, on: req)
            .flatMap { self.sendNotification(user: user, allowance: $0, on: req) }
    }

    func sendNotification(user: User, allowance: Double, on req: Request) -> EventLoopFuture<[Data]> {
        user.deviceTokens
            .map {
                self.sendNotification(deviceToken: $0,
                                      allowance: allowance,
                                      on: req)
            }.flatten(on: req.eventLoop)
    }

    func sendNotification(deviceToken: String, allowance: Double, on req: Request) -> EventLoopFuture<Data> {
        //let payload = "{\"aps\":{\"content-available\":1},\"allowance\":\(allowance)}"
        req.eventLoop.makeSucceededFuture(Data())
    }

    func addRoutes(to router: RoutesBuilder) {
        router.post(Routes.deviceToken.path, use: store)
    }
}
