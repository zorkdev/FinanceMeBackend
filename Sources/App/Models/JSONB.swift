import FluentPostgresDriver

struct JSONB: Codable {
    let data: Data
}

extension JSONB: PostgresDataConvertible {
    static var postgresDataType: PostgresDataType { .jsonb }

    var postgresData: PostgresData? { .init(jsonb: data) }

    init?(postgresData: PostgresData) {
        guard let data = postgresData.jsonb else { return nil }
        self.data = data
    }
}
