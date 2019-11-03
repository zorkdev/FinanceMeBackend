import Vapor
import Authentication

final class UserController {
    private let spendingBusinessLogic = SpendingBusinessLogic()
    private let pushNotificationController = PushNotificationController()
    private let starlingBalanceController = StarlingBalanceController()

    func showCurrentUser(_ req: Request) throws -> Future<UserResponse> {
        let user = try req.requireAuthenticated(User.self)

        let allowance = try spendingBusinessLogic.calculateAllowance(for: user, on: req)
        let balance = try starlingBalanceController
            .getBalance(user: user, on: req)
            .map { $0.effectiveBalance }

        return [allowance, balance]
            .flatten(on: req)
            .map { results in
                var userResponse = user.response
                userResponse.allowance = results[0]
                userResponse.balance = results[1]
                return userResponse
        }
    }

    func store(_ req: Request) throws -> Future<UserResponse> {
        return try req.content.decode(UserRequest.self)
            .flatMap { userRequest in
                let hasher = try req.make(BCryptDigest.self)
                let password = try hasher.hash(userRequest.password, cost: 7)

                let user = User(name: userRequest.name,
                                email: userRequest.email,
                                password: password,
                                payday: userRequest.payday,
                                startDate: userRequest.startDate,
                                largeTransaction: userRequest.largeTransaction,
                                sToken: nil,
                                customerUid: nil,
                                deviceTokens: [])

                return user.save(on: req)
                    .flatMap { user in
                        let token = try Token.generate(for: user)
                        return token.save(on: req)
                            .transform(to: user.response)
                    }
        }
    }

    func updateCurrentUser(_ req: Request) throws -> Future<UserResponse> {
        let user = try req.requireAuthenticated(User.self)
        return try req.content.decode(UserResponse.self)
            .flatMap { updatedUser in
                user.name = updatedUser.name
                user.largeTransaction = updatedUser.largeTransaction
                user.payday = updatedUser.payday
                user.startDate = updatedUser.startDate
                return user.save(on: req)
            }.flatMap { try self.spendingBusinessLogic.calculateAllowance(for: $0, on: req) }
            .flatMap{ allowance in
                try self.starlingBalanceController
                    .getBalance(user: user, on: req)
                    .map { (allowance, $0.effectiveBalance) }
            }.flatMap { (allowance, balance) in
                return try self.pushNotificationController.sendNotification(user: user,
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

    func loginUser(_ req: Request) throws -> Future<Session> {
        return try req.content.decode(LoginRequest.self)
            .flatMap { loginRequest -> Future<User?> in
                let verifier = try req.make(BCryptDigest.self)
                return User.authenticate(username: loginRequest.email,
                                         password: loginRequest.password,
                                         using: verifier,
                                         on: req)
            }.flatMap { user in
                guard let user = user else { throw Abort(.internalServerError) }
                return try user.token
                    .query(on: req)
                    .first()
                    .map { token in
                        guard let token = token else { throw Abort(.internalServerError) }
                        return Session(token: token.token)
                }
        }
    }

    func addPublicRoutes(to router: Router) {
        router.post(Routes.users.rawValue, use: store)
        router.post(Routes.login.rawValue, use: loginUser)
    }

    func addRoutes(to router: Router) {
        router.get(Routes.usersMe.rawValue, use: showCurrentUser)
        router.patch(Routes.usersMe.rawValue, use: updateCurrentUser)
    }
}
