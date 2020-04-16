import Vapor
import Fluent

final class TransactionController {
    private let transactionsBusinessLogic = TransactionsBusinessLogic()
    private let pushNotificationController = PushNotificationController()

    func index(_ req: Request) throws -> EventLoopFuture<[TransactionResponse]> {
        let user = try req.auth.require(User.self)
        return transactionsBusinessLogic.getExternalTransactions(for: user, on: req.db)
            .map { $0.map { $0.response } }
    }

    func show(_ req: Request) throws -> EventLoopFuture<TransactionResponse> {
        let user = try req.auth.require(User.self)
        guard let transactionId = req.parameters.get(Routes.Parameters.transaction.rawValue, as: UUID.self) else {
            return req.eventLoop.makeFailedFuture(Abort(.notFound))
        }
        return Transaction.find(transactionId, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMapThrowing {
                guard $0.$user.id == user.id else { throw Abort(.notFound) }
                return $0.response
            }
    }

    func store(_ req: Request) throws -> EventLoopFuture<TransactionResponse> {
        let user = try req.auth.require(User.self)
        let transactionResponse = try req.content.decode(TransactionResponse.self)
        guard let userID = user.id else { throw Abort(.notFound) }

        let transaction = Transaction(amount: transactionResponse.amount,
                                      direction: transactionResponse.direction,
                                      created: transactionResponse.created,
                                      narrative: transactionResponse.narrative,
                                      source: transactionResponse.source,
                                      isArchived: false,
                                      internalNarrative: nil,
                                      internalAmount: nil,
                                      userID: userID)

        return transaction.save(on: req.db)
            .flatMap { self.pushNotificationController.sendNotification(user: user, on: req) }
            .transform(to: transaction.response)
    }

    func replace(_ req: Request) throws -> EventLoopFuture<TransactionResponse> {
        let user = try req.auth.require(User.self)
        let transactionResponse = try req.content.decode(TransactionResponse.self)

        guard let transactionId = req.parameters.get(Routes.Parameters.transaction.rawValue, as: UUID.self),
            let userID = user.id else {
                return req.eventLoop.makeFailedFuture(Abort(.notFound))
        }

        return Transaction.find(transactionId, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMapThrowing {
                guard $0.$user.id == userID else { throw Abort(.notFound) }
                return $0
            }.flatMap { (transaction: Transaction) -> EventLoopFuture<TransactionResponse> in
                transaction.amount = transactionResponse.amount
                transaction.direction = transactionResponse.direction
                transaction.created = transactionResponse.created
                transaction.narrative = transactionResponse.narrative
                transaction.source = transactionResponse.source
                return transaction.save(on: req.db)
                    .flatMap { self.pushNotificationController.sendNotification(user: user, on: req) }
                    .transform(to: transaction.response)
            }
    }

    func destroy(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let user = try req.auth.require(User.self)

        guard let transactionId = req.parameters.get(Routes.Parameters.transaction.rawValue, as: UUID.self),
            let userID = user.id else {
                return req.eventLoop.makeFailedFuture(Abort(.notFound))
        }

        return Transaction.find(transactionId, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMapThrowing {
                guard $0.$user.id == userID else { throw Abort(.notFound) }
                return $0
            }.flatMap { (transaction: Transaction) -> EventLoopFuture<Void> in
                transaction.delete(on: req.db)
            }.flatMap {
                self.pushNotificationController.sendNotification(user: user, on: req)
            }.transform(to: .ok)
    }

    func handlePayload(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        if let payload = try? req.content.decode(TransactionPayload.self) {
            // swiftlint:disable:next first_where
            _ = User
                .query(on: req.db)
                .filter(\.$customerUid == payload.customerUid)
                .first()
                .unwrap(or: Abort(.notFound))
                .flatMap { user in
                    self.transactionsBusinessLogic.getTransactions(user: user, on: req)
                        .flatMap { _ in self.pushNotificationController.sendNotification(user: user, on: req) }
                }.flatMapErrorThrowing { error in
                    req.logger.error("\(error)")
                    throw error
                }
        }

        return req.eventLoop.makeSucceededFuture(.ok)
    }

    func addPublicRoutes(to router: RoutesBuilder) {
        router.post(Routes.transactions.path, Routes.transactionPayload.path, use: handlePayload)
    }

    func addRoutes(to router: RoutesBuilder) {
        router.get(Routes.transactions.path, use: index)
        router.get(Routes.transactions.path, Routes.Parameters.transaction.path, use: show)
        router.post(Routes.transactions.path, use: store)
        router.put(Routes.transactions.path, Routes.Parameters.transaction.path, use: replace)
        router.delete(Routes.transactions.path, Routes.Parameters.transaction.path, use: destroy)
    }
}
