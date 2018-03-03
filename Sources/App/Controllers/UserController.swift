import Vapor
import AuthProvider

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
        guard let email = req.json?[User.Constants.emailKey]?.string,
            let password = req.json?[User.Constants.passwordKey]?.string else {
                throw Abort.unauthorized
        }

        let credentials = Password(username: email, password: password)
        let user = try User.authenticate(credentials)
        let json = try user.makeLoginJSON()
        return json
    }

    func addPublicRoutes(to group: RouteBuilder) {
        group.add(.post, Routes.users.rawValue, value: store)
        group.add(.post, Routes.login.rawValue, value: loginUser)
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
