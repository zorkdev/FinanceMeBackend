import Vapor

enum Routes: String {
    enum Parameters: String {
        case transaction = "transactionId"

        var path: PathComponent { .parameter(rawValue) }
    }

    case api = "api"
    case login = "login"
    case users = "users"
    case usersMe = "me"
    case transactions = "transactions"
    case transactionPayload = "payload"
    case reconcile = "reconcile"
    case endOfMonthSummaries = "endOfMonthSummaries"
    case deviceToken = "deviceToken"
    case metrics = "metrics"
    case health = "health"

    var path: PathComponent { .constant(rawValue) }
}

func routes(_ app: Application) throws {
    let apiGroup = app.grouped(Routes.api.path)
    let tokenGroup = apiGroup.grouped(Token.authenticator(), Token.guardMiddleware())

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
