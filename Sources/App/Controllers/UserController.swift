//
//  UserController.swift
//  App
//
//  Created by Attila Nemet on 15/10/2017.
//

import Vapor
import FluentProvider

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

    func addPublicRoutes(to group: RouteBuilder) throws {
        group.add(.post, "users", value: store)
    }

    func addRoutes(to group: RouteBuilder) throws {
        group.add(.get, "users/me", value: showCurrentUser)
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
