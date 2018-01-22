//
//  UserController.swift
//  App
//
//  Created by Attila Nemet on 15/10/2017.
//

import Vapor
import FluentProvider

final class UserController: ResourceRepresentable {

    func index(_ req: Request) throws -> ResponseRepresentable {
        return try User.all().makeJSON()
    }

    func show(_ req: Request, user: User) throws -> ResponseRepresentable {
        return user
    }

    func store(_ req: Request) throws -> ResponseRepresentable {
        let user = try req.user()
        try user.save()
        let token = try Token.generate(for: user)
        try token.save()
        return user
    }

    func makeResource() -> Resource<User> {
        return Resource(
            index: index,
            show: show
        )
    }

    func addPublicRoutes(to group: RouteBuilder) throws {
        group.add(.post, "users", value: store)
    }

    func addRoutes(to group: RouteBuilder) throws {
        try group.resource("users", UserController.self)
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
