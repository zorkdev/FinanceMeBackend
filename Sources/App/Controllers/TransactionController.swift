import Vapor

final class TransactionController: ResourceRepresentable {

    private let transactionsBusinessLogic = TransactionsBusinessLogic()

    func index(_ req: Request) throws -> ResponseRepresentable {
        let user = try req.authUser()
        let transactions = try transactionsBusinessLogic.getExternalTransactions(for: user)
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

    func replace(_ req: Request, transaction: Transaction) throws -> ResponseRepresentable {
        let updatedTransaction = try req.transaction()
        let user = try req.authUser()
        guard transaction.userId == user.id else { throw Abort.notFound }
        updatedTransaction.userId = user.id
        try transaction.delete()
        try updatedTransaction.save()
        return updatedTransaction
    }

    func destroy(_ req: Request, transaction: Transaction) throws -> ResponseRepresentable {
        let user = try req.authUser()
        guard transaction.userId == user.id else { throw Abort.notFound }
        try transaction.delete()
        return Response(status: .ok)
    }

    func makeResource() -> Resource<Transaction> {
        return Resource(
            index: index,
            store: store,
            show: show,
            replace: replace,
            destroy: destroy
        )
    }

    func handlePayload(_ req: Request) throws -> ResponseRepresentable {
        return try Response.async { portal in
            portal.close(with: Response(status: .ok))
            
            let transactionPayload = try req.transactionPayload()
            guard let user = try User
                .makeQuery()
                .filter(User.Constants.customerUidKey,
                        .equals,
                        transactionPayload.customerUid)
                .first() else {
                    return
            }
            _ = try? self.transactionsBusinessLogic.getTransactions(user: user)
        }
    }

    func addPublicRoutes(to group: RouteBuilder) {
        group.add(.post, Routes.transactionPayload.rawValue, value: handlePayload)
    }

    func addRoutes(to group: RouteBuilder) throws {
        try group.resource(Routes.transactions.rawValue, TransactionController.self)
    }

}

extension TransactionController: EmptyInitializable {}

extension Request {

    func transaction() throws -> Transaction {
        guard let json = json else { throw Abort.badRequest }
        return try Transaction(json: json)
    }

    func transactionPayload() throws -> TransactionPayload {
        guard let json = json else { throw Abort.badRequest }
        return try TransactionPayload(json: json)
    }

}
