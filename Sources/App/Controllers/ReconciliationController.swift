import Vapor

final class ReconciliationController {
    private let spendingBusinessLogic = SpendingBusinessLogic()
    private let transactionsBusinessLogic = TransactionsBusinessLogic()
    private let pushNotificationController = PushNotificationController()

    func store(_ req: Request) throws -> Future<HTTPStatus> {
        _ = User
            .query(on: req)
            .all()
            .flatMap { users in
                try users.map { user in
                    try self.spendingBusinessLogic.updateDailySpendingAverage(user: user, on: req)
                        .flatMap { _ in try self.transactionsBusinessLogic.updateTransactions(user: user, on: req) }
                        .flatMap { _ in try self.spendingBusinessLogic.calculateEndOfMonthBalance(for: user, on: req) }
                        .flatMap { _ in
                            try self.pushNotificationController.sendNotification(user: user, on: req)
                        }
                }.flatten(on: req)
            }.catch { try? req.make(Logger.self).error("\($0)") }

        return req.eventLoop.newSucceededFuture(result: .ok)
    }

    func addRoutes(to router: Router) {
        router.post(Routes.reconcile.rawValue, use: store)
    }
}
