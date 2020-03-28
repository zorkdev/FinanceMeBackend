import Vapor
import Fluent
import FluentPostgresDriver

extension FieldKey {
    static var payload: Self { "payload" }
}

final class Metric: Model {
    static let schema = "metrics"

    @ID()
    var id: UUID?

    @Field(key: .payload)
    var payload: JSONB

    init() {}

    init(id: UUID? = nil,
         payload: Data) {
        self.id = id
        self.payload = JSONB(data: payload)
    }
}

struct CreateMetric: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Metric.schema)
            .id()
            .field(.payload, .custom(PostgresDataType.jsonb), .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Metric.schema).delete()
    }
}
