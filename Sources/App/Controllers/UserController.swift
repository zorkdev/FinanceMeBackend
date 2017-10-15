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
        return user
    }

    func makeResource() -> Resource<User> {
        return Resource(
            index: index,
            store: store,
            show: show
        )
    }

    func indexReminders(_ req: Request) throws -> ResponseRepresentable {
        let user = try req.parameters.next(User.self)
        return try user.reminders.all().makeJSON()
    }

    func addRoutes(to group: RouteBuilder) throws {
        try group.resource("users", UserController.self)
        let userGroup = group.grouped("users")
        userGroup.get(User.parameter, "reminders", handler: indexReminders)
    }

}

extension UserController: EmptyInitializable {}

extension Request {

    func user() throws -> User {
        guard let json = json else { throw Abort.badRequest }
        return try User(json: json)
    }
    
}
