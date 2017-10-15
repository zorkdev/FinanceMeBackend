//
//  ReminderController.swift
//  App
//
//  Created by Attila Nemet on 15/10/2017.
//

import Vapor
import FluentProvider

final class ReminderController: ResourceRepresentable {

    func index(_ req: Request) throws -> ResponseRepresentable {
        return try Reminder.all().makeJSON()
    }

    func show(_ req: Request, reminder: Reminder) throws -> ResponseRepresentable {
        return reminder
    }

    func store(_ req: Request) throws -> ResponseRepresentable {
        let reminder = try req.reminder()
        try reminder.save()

        if let json = req.json, let categories = json["categories"]?.array {
            for categoryJSON in categories {
                if let category = try Category.find(categoryJSON["id"]) {
                    try reminder.categories.add(category)
                }
            }
        }

        return reminder
    }

    func makeResource() -> Resource<Reminder> {
        return Resource(
            index: index,
            store: store,
            show: show
        )
    }

    func indexCategories(_ req: Request) throws -> ResponseRepresentable {
        let reminder = try req.parameters.next(Reminder.self)
        return try reminder.categories.all().makeJSON()
    }

    func addRoutes(to group: RouteBuilder) throws {
        try group.resource("reminders", ReminderController.self)
        let reminderGroup = group.grouped("reminders")
        reminderGroup.get(Reminder.parameter, "categories", handler: indexCategories)
    }
    
}

extension ReminderController: EmptyInitializable {}

extension Request {

    func reminder() throws -> Reminder {
        guard let json = json else { throw Abort.badRequest }
        return try Reminder(json: json)
    }

}
