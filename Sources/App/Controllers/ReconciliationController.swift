//
//  ReconciliationController.swift
//  App
//
//  Created by Attila Nemet on 24/01/2018.
//

import Vapor
import FluentProvider

final class ReconciliationController {

    private let starlingTransactionsController = StarlingTransactionsController()

    func store(_ req: Request) throws -> ResponseRepresentable {
        let users = try User.all()

        for user in users {
            let transactions = try starlingTransactionsController.getTransactions(user: user)
            print(transactions)
        }

        return Response(status: .ok)
    }

    func addRoutes(to group: RouteBuilder) {
        group.add(.post, "reconcile", value: store)
    }

}

extension ReconciliationController: EmptyInitializable {}
