import Vapor
import FluentPostgreSQL

final class TransactionController {
    private let transactionsBusinessLogic = TransactionsBusinessLogic()
    private let pushNotificationController = PushNotificationController()

    func index(_ req: Request) throws -> Future<[TransactionResponse]> {
        let user = try req.requireAuthenticated(User.self)
        return try transactionsBusinessLogic.getExternalTransactions(for: user, on: req)
            .map { $0.map { $0.response } }
    }

    func show(_ req: Request) throws -> Future<TransactionResponse> {
        let user = try req.requireAuthenticated(User.self)

        return try req.parameters.next(Transaction.self)
            .flatMap { transaction in
                guard transaction.userID == user.id else { throw Abort(.notFound) }
                return req.eventLoop.newSucceededFuture(result: transaction.response)
            }
    }

    func store(_ req: Request) throws -> Future<TransactionResponse> {
        let user = try req.requireAuthenticated(User.self)
        guard let userID = user.id else { throw Abort(.notFound) }

        return try req.content.decode(TransactionResponse.self)
            .flatMap { transactionResponse in
                let transaction = Transaction(amount: transactionResponse.amount,
                                              direction: transactionResponse.direction,
                                              created: transactionResponse.created,
                                              narrative: transactionResponse.narrative,
                                              source: transactionResponse.source,
                                              isArchived: false,
                                              internalNarrative: nil,
                                              internalAmount: nil,
                                              userID: userID)

                return transaction.save(on: req)
                    .flatMap { transaction in
                        try self.pushNotificationController.sendNotification(user: user, on: req)
                            .map { _ in transaction.response }
                    }
            }
    }

    func replace(_ req: Request) throws -> Future<TransactionResponse> {
        let user = try req.requireAuthenticated(User.self)
        guard let userID = user.id else { throw Abort(.notFound) }

        return try req.parameters.next(Transaction.self)
            .flatMap { transaction -> Future<TransactionResponse> in
                guard transaction.userID == userID else { throw Abort(.notFound) }
                return try req.content.decode(TransactionResponse.self)
                    .flatMap { transactionResponse in
                        transaction.amount = transactionResponse.amount
                        transaction.direction = transactionResponse.direction
                        transaction.created = transactionResponse.created
                        transaction.narrative = transactionResponse.narrative
                        transaction.source = transactionResponse.source
                        return transaction.save(on: req).flatMap { _ in
                            try self.pushNotificationController.sendNotification(user: user, on: req)
                        }.map { _ in transaction.response }
                    }
            }
    }

    func destroy(_ req: Request) throws -> Future<HTTPStatus> {
        let user = try req.requireAuthenticated(User.self)
        guard let userID = user.id else { throw Abort(.notFound) }

        return try req.parameters.next(Transaction.self)
            .flatMap { transaction -> Future<Void> in
                guard transaction.userID == userID else { throw Abort(.notFound) }
                return transaction.delete(on: req)
            }.flatMap { _ in
                try self.pushNotificationController.sendNotification(user: user, on: req)
            }.transform(to: .ok)
    }

    func handlePayload(_ req: Request) throws -> Future<HTTPStatus> {
        _ = try? req.content.decode(TransactionPayload.self)
            .flatMap { payload -> Future<[Data]> in
                // swiftlint:disable:next first_where
                return User
                    .query(on: req)
                    .filter(\.customerUid == payload.customerUid)
                    .first()
                    .flatMap { user in
                        guard let user = user else { throw Abort(.notFound) }
                        return try self.transactionsBusinessLogic.getTransactions(user: user, on: req)
                            .flatMap { _ in
                                try self.pushNotificationController.sendNotification(user: user, on: req)
                            }
                    }
            }.catch { try? req.make(Logger.self).error("\($0)") }

        return req.eventLoop.newSucceededFuture(result: .ok)
    }

    func addPublicRoutes(to router: Router) {
        router.post(Routes.transactionPayload.rawValue, use: handlePayload)
    }

    func addRoutes(to router: Router) {
        router.get(Routes.transactions.rawValue, use: index)
        router.get(Routes.transactions.rawValue, Transaction.parameter, use: show)
        router.post(Routes.transactions.rawValue, use: store)
        router.put(Routes.transactions.rawValue, Transaction.parameter, use: replace)
        router.delete(Routes.transactions.rawValue, Transaction.parameter, use: destroy)
    }
}
