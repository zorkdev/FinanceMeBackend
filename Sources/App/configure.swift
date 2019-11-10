import FluentPostgreSQL
import Vapor
import Authentication

public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    services.register(NIOServerConfig.default(workerCount: 4, supportCompression: true))
    services.register(DatabaseConnectionPoolConfig(maxConnections: 4))

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
    migrations.add(model: Metric.self, database: .psql)
    services.register(migrations)

    let apnsCert = ProcessInfo.processInfo.environment["APNS_CERT"]!.data(using: .utf8)!
    let directory = DirectoryConfig.detect()
    let workingDirectory = directory.workDir
    let saveURL = URL(fileURLWithPath: workingDirectory).appendingPathComponent("apns.pem", isDirectory: false)
    try apnsCert.write(to: saveURL)
}
