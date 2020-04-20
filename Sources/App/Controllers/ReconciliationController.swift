import Vapor

final class ReconciliationController {
    private let spendingBusinessLogic = SpendingBusinessLogic()
    private let transactionsBusinessLogic = TransactionsBusinessLogic()
    private let pushNotificationController = PushNotificationController()

    func store(_ req: Request) -> EventLoopFuture<HTTPStatus> {
        _ = User
            .query(on: req.db)
            .all()
            .flatMap { users in
                users.map { user in
                    self.transactionsBusinessLogic.updateTransactions(user: user, on: req)
                        .flatMap { _ in self.spendingBusinessLogic.calculateEndOfMonthBalance(for: user, on: req.db) }
                        .flatMap { self.pushNotificationController.sendNotification(user: user, on: req) }
                }.flatten(on: req.eventLoop)
            }.flatMapErrorThrowing { error in
                req.logger.error("\(error)")
                throw error
            }

        return req.eventLoop.makeSucceededFuture(.ok)
    }

    func addRoutes(to router: RoutesBuilder) {
        router.post(Routes.reconcile.path, use: store)
    }
}
