import Vapor

struct TransactionPayload: Content {
    let customerUid: String
}
