//
//  TransactionController.swift
//  App
//
//  Created by Attila Nemet on 22/01/2018.
//

import Vapor
import FluentProvider

final class TransactionController: ResourceRepresentable {

    func index(_ req: Request) throws -> ResponseRepresentable {
        let user = try req.authUser()
        let transactions = try Transaction.all().filter({ $0.userId == user.id })
        return try transactions.makeJSON()
    }

    func show(_ req: Request, transaction: Transaction) throws -> ResponseRepresentable {
        let user = try req.authUser()
        guard transaction.userId == user.id else { throw Abort.notFound }
        return transaction
    }

    func store(_ req: Request) throws -> ResponseRepresentable {
        let transaction = try req.transaction()
        let user = try req.authUser()
        transaction.userId = user.id
        try transaction.save()
        return transaction
    }

    func makeResource() -> Resource<Transaction> {
        return Resource(
            index: index,
            store: store,
            show: show
        )
    }

    func indexTransactionsSummary(_ req: Request) throws -> ResponseRepresentable {
        let user = try req.authUser()
        let transactions = try Transaction.all().filter({ $0.userId == user.id })
        let sumAmount = transactions.flatMap({ $0.amount }).reduce(0, +)
        let transactionsSummary = TransactionsSummary(sumAmount: sumAmount)
        return try transactionsSummary.makeJSON()
    }

    func addRoutes(to group: RouteBuilder) throws {
        try group.resource("transactions", TransactionController.self)
        let transactionsGroup = group.grouped("transactions")
        transactionsGroup.get("summary", handler: indexTransactionsSummary)
    }

}

extension TransactionController: EmptyInitializable {}

extension Request {

    func transaction() throws -> Transaction {
        guard let json = json else { throw Abort.badRequest }
        return try Transaction(json: json)
    }

}
