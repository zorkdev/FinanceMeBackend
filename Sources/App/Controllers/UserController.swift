import Vapor

final class UserController {

    func showCurrentUser(_ req: Request) throws -> ResponseRepresentable {
        let user = try req.authUser()
        return user
    }

    func store(_ req: Request) throws -> ResponseRepresentable {
        let user = try req.user()
        try user.save()
        let token = try Token.generate(for: user)
        try token.save()
        return user
    }

    func addPublicRoutes(to group: RouteBuilder) {
        group.add(.post, Routes.users.rawValue, value: store)
    }

    func addRoutes(to group: RouteBuilder) {
        group.add(.get, Routes.usersMe.rawValue, value: showCurrentUser)
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
