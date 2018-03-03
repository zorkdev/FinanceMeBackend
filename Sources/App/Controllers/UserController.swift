import Vapor

final class UserController {

    private struct Constants {
        static let allowanceKey = "allowance"
    }

    private let spendingBusinessLogic = SpendingBusinessLogic()

    func showCurrentUser(_ req: Request) throws -> ResponseRepresentable {
        let user = try req.authUser()
        var json = try user.makeJSON()
        let allowance = try spendingBusinessLogic.calculateAllowance(for: user)
        try json.set(Constants.allowanceKey, allowance)
        return json
    }

    func store(_ req: Request) throws -> ResponseRepresentable {
        let user = try req.user()
        try user.save()
        let token = try Token.generate(for: user)
        try token.save()
        return user
    }

    func updateCurrentUser(_ req: Request) throws -> ResponseRepresentable {
        let user = try req.authUser()
        let updatedUser = try req.user()
        user.name = updatedUser.name
        user.largeTransaction = updatedUser.largeTransaction
        user.payday = updatedUser.payday
        user.startDate = updatedUser.startDate
        try user.save()
        var json = try user.makeJSON()
        let allowance = try spendingBusinessLogic.calculateAllowance(for: user)
        try json.set(Constants.allowanceKey, allowance)
        return json
    }

    func loginUser(_ req: Request) throws -> ResponseRepresentable {
        let user = try req.authUser()
        let json = try user.makeLoginJSON()
        return json
    }

    func addPublicRoutes(to group: RouteBuilder) {
        group.add(.post, Routes.users.rawValue, value: store)
    }

    func addLoginRoutes(to group: RouteBuilder) {
        group.add(.get, Routes.login.rawValue, value: loginUser)
    }

    func addRoutes(to group: RouteBuilder) {
        group.add(.get, Routes.usersMe.rawValue, value: showCurrentUser)
        group.add(.patch, Routes.usersMe.rawValue, value: updateCurrentUser)
    }

}

extension UserController: EmptyInitializable {}

extension Request {

    func user() throws -> User {
        guard let json = json else { throw Abort.badRequest }
        return try User(json: json)
    }

    func authUser() throws -> User {
        return try auth.assertAuthenticated()
    }

}
