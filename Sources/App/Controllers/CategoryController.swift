//
//  CategoryController.swift
//  App
//
//  Created by Attila Nemet on 15/10/2017.
//

import Vapor
import FluentProvider

final class CategoryController: ResourceRepresentable {

    func index(_ req: Request) throws -> ResponseRepresentable {
        return try Category.all().makeJSON()
    }

    func show(_ req: Request, category: Category) throws -> ResponseRepresentable {
        return category
    }

    func store(_ req: Request) throws -> ResponseRepresentable {
        let category = try req.category()
        try category.save()
        return category
    }

    func makeResource() -> Resource<Category> {
        return Resource(
            index: index,
            store: store,
            show: show
        )
    }

    func indexReminders(_ req: Request) throws -> ResponseRepresentable {
        let category = try req.parameters.next(Category.self)
        return try category.reminders.all().makeJSON()
    }

    func addRoutes(to group: RouteBuilder) throws {
        try group.resource("categories", CategoryController.self)
        let categoryGroup = group.grouped("categories")
        categoryGroup.get(Category.parameter, "reminders", handler: indexReminders)
    }

}

extension CategoryController: EmptyInitializable {}

extension Request {

    func category() throws -> Category {
        guard let json = json else { throw Abort.badRequest }
        return try Category(json: json)
    }

}
