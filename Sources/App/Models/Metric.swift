import Vapor
import FluentPostgreSQL

final class Metric: PostgreSQLUUIDModel {
    static let entity = "metrics"

    var id: UUID?
    var payload: JSONB

    init(id: UUID? = nil,
         payload: Data) {
        self.id = id
        self.payload = JSONB(data: payload)
    }
}

extension Metric: Migration {}
