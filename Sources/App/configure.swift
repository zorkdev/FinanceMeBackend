import FluentPostgreSQL
import Vapor
import Authentication

public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    try services.register(FluentPostgreSQLProvider())
    try services.register(AuthenticationProvider())

    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    var middlewares = MiddlewareConfig()
    middlewares.use(FileMiddleware.self)
    middlewares.use(ErrorMiddleware.self)
    services.register(middlewares)

    let databaseURL = ProcessInfo.processInfo.environment["DATABASE_URL"]!
    let psqlConfig = PostgreSQLDatabaseConfig(url: databaseURL, transport: .unverifiedTLS)!
    services.register(psqlConfig)

    var migrations = MigrationConfig()
    migrations.add(model: Transaction.self, database: .psql)
    migrations.add(model: EndOfMonthSummary.self, database: .psql)
    migrations.add(model: Token.self, database: .psql)
    migrations.add(model: User.self, database: .psql)
    services.register(migrations)

    var contentConfig = ContentConfig.default()
    let jsonDecoder = JSONDecoder()
    jsonDecoder.dateDecodingStrategy = .formatted(Date.iso8601MillisecFormatter)
    contentConfig.use(decoder: jsonDecoder, for: .json)
    let jsonEncoder = JSONEncoder()
    jsonEncoder.dateEncodingStrategy = .formatted(Date.iso8601MillisecFormatter)
    contentConfig.use(encoder: jsonEncoder, for: .json)
    services.register(contentConfig)
}
