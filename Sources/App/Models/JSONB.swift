import Vapor
import FluentPostgreSQL

struct JSONB: Codable, Equatable, ReflectionDecodable, PostgreSQLDataConvertible {
    let data: Data

    static func reflectDecoded() throws -> (JSONB, JSONB) {
        return (JSONB(data: Data([1])), JSONB(data: Data([2])))
    }

    static func convertFromPostgreSQLData(_ data: PostgreSQLData) throws -> JSONB {
        guard let binary = data.binary else { throw PostgreSQLError(identifier: "Null data", reason: "") }
        return JSONB(data: binary)
    }

    func convertToPostgreSQLData() throws -> PostgreSQLData {
        return PostgreSQLData(.jsonb, binary: [0x01] + data)
    }
}
