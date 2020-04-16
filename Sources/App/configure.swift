import Vapor
import Fluent
import FluentPostgresDriver

extension PostgresConfiguration {
    init?(url: URL, tlsConfiguration: TLSConfiguration?) {
        guard url.scheme?.hasPrefix("postgres") == true,
            let username = url.user,
            let password = url.password,
            let hostname = url.host,
            let port = url.port else { return nil }
        self.init(
            hostname: hostname,
            port: port,
            username: username,
            password: password,
            database: url.path.split(separator: "/").last.flatMap(String.init),
            tlsConfiguration: tlsConfiguration
        )
    }
}

public func configure(_ app: Application) throws {
    app.http.server.configuration.requestDecompression = .enabled
    app.http.server.configuration.responseCompression = .enabled

    let databaseURL = URL(string: Environment.get("DATABASE_URL")!)!
    let databaseConfig = PostgresConfiguration(url: databaseURL,
                                               tlsConfiguration: .forClient(certificateVerification: .none))!
    app.databases.use(.postgres(configuration: databaseConfig), as: .psql)

    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))

    app.migrations.add(CreateTransaction())
    app.migrations.add(CreateEndOfMonthSummary())
    app.migrations.add(CreateToken())
    app.migrations.add(CreateUser())
    app.migrations.add(CreateMetric())

    try routes(app)
}
