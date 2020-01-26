import Vapor
import Authentication

enum Routes: String {
    case api = "api"
    case login = "login"
    case users = "users"
    case usersMe = "users/me"
    case transactions = "transactions"
    case transactionPayload = "transactions/payload"
    case reconcile = "reconcile"
    case endOfMonthSummaries = "endOfMonthSummaries"
    case deviceToken = "deviceToken"
    case metrics = "metrics"
    case health = "health"
}

public func routes(_ router: Router) throws {
    let apiGroup = router.grouped(Routes.api.rawValue)
    let tokenGroup = apiGroup.grouped(User.tokenAuthMiddleware())

    let userController = UserController()
    userController.addRoutes(to: tokenGroup)
    userController.addPublicRoutes(to: apiGroup)

    let transactionController = TransactionController()
    transactionController.addRoutes(to: tokenGroup)
    transactionController.addPublicRoutes(to: apiGroup)

    let reconciliationController = ReconciliationController()
    reconciliationController.addRoutes(to: apiGroup)

    let endOfMonthSummaryController = EndOfMonthSummaryController()
    endOfMonthSummaryController.addRoutes(to: tokenGroup)

    let pushNotificationController = PushNotificationController()
    pushNotificationController.addRoutes(to: tokenGroup)

    let metricController = MetricController()
    metricController.addPublicRoutes(to: apiGroup)

    let healthController = HealthController()
    healthController.addPublicRoutes(to: apiGroup)
}