import Vapor

struct HALResponse<T: Content>: Content {

    enum CodingKeys: String, CodingKey {
        case embedded = "_embedded"
    }

    let embedded: T

}

struct TransactionList: Content {

    let transactions: [StarlingTransaction]

}

struct StarlingTransaction: Content {

    let id: UUID
    let amount: Double
    let direction: TransactionDirection
    let created: Date
    let narrative: String
    let source: TransactionSource?

}
