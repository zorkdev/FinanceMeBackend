import Vapor
import Fluent

final class UserController {
    private let spendingBusinessLogic = SpendingBusinessLogic()
    private let pushNotificationController = PushNotificationController()
    private let starlingBalanceController = StarlingBalanceController()

    func showCurrentUser(_ req: Request) throws -> EventLoopFuture<UserResponse> {
        let user = try req.auth.require(User.self)
        let allowance = spendingBusinessLogic.calculateAllowance(for: user, on: req)
        let balance = starlingBalanceController
            .getBalance(user: user, on: req)
            .map { $0.effectiveBalance.doubleValue }

        return [allowance, balance]
            .flatten(on: req.eventLoop)
            .map { results in
                var userResponse = user.response
                userResponse.allowance = results[0]
                userResponse.balance = results[1]
                return userResponse
            }
    }

    func store(_ req: Request) throws -> EventLoopFuture<UserResponse> {
        let userRequest = try req.content.decode(UserRequest.self)
        let password = try Bcrypt.hash(userRequest.password, cost: 7)

        let user = User(name: userRequest.name,
                        email: userRequest.email,
                        password: password,
                        payday: userRequest.payday,
                        startDate: userRequest.startDate,
                        largeTransaction: userRequest.largeTransaction,
                        sToken: nil,
                        customerUid: nil,
                        deviceTokens: [],
                        dailySpendingAverage: 0,
                        dailyTravelSpendingAverage: 0)

        return user.save(on: req.db)
            .flatMapThrowing {
                try user.generateToken()
            }.flatMap { token in
                return token.save(on: req.db)
                    .transform(to: user.response)
            }
    }

    func updateCurrentUser(_ req: Request) throws -> EventLoopFuture<UserResponse> {
        let user = try req.auth.require(User.self)
        let updatedUser = try req.content.decode(UserResponse.self)

        user.name = updatedUser.name
        user.largeTransaction = updatedUser.largeTransaction
        user.payday = updatedUser.payday
        user.startDate = updatedUser.startDate

        return user.save(on: req.db)
            .flatMap { self.spendingBusinessLogic.calculateAllowance(for: user, on: req) }
            .flatMap { allowance in
                self.starlingBalanceController
                    .getBalance(user: user, on: req)
                    .map { (allowance, $0.effectiveBalance.doubleValue) }
            }.flatMap { allowance, balance in
                self.pushNotificationController.sendNotification(user: user,
                                                                 allowance: allowance,
                                                                 on: req)
                    .map { _ in
                        var userResponse = user.response
                        userResponse.allowance = allowance
                        userResponse.balance = balance
                        return userResponse
                    }
            }
    }

    func loginUser(_ req: Request) throws -> EventLoopFuture<Session> {
        let loginRequest = try req.content.decode(LoginRequest.self)

        return User
            .query(on: req.db)
            .filter(\.$email == loginRequest.email)
            .first()
            .unwrap(or: Abort(.unauthorized))
            .flatMapThrowing { (user: User) -> User in
                guard try user.verify(password: loginRequest.password) else { throw Abort(.notFound) }
                return user
            }.flatMap { user in
                user.$tokens
                    .query(on: req.db)
                    .first()
                    .unwrap(or: Abort(.notFound))
                    .map { Session(token: $0.token) }
            }
    }

    func addPublicRoutes(to router: RoutesBuilder) {
        router.post(Routes.users.path, use: store)
        router.post(Routes.login.path, use: loginUser)
    }

    func addRoutes(to router: RoutesBuilder) {
        router.get(Routes.users.path, Routes.usersMe.path, use: showCurrentUser)
        router.patch(Routes.users.path, Routes.usersMe.path, use: updateCurrentUser)
    }
}
