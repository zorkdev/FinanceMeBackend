import Vapor

final class TransactionPayload {

    struct Constants {
        static let customerUidKey = "customerUid"
    }

    let customerUid: String

    init(customerUid: String) {
        self.customerUid = customerUid
    }

}

extension TransactionPayload: JSONConvertible {

    convenience init(json: JSON) throws {
        try self.init(customerUid: json.get(Constants.customerUidKey))
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Constants.customerUidKey, customerUid)
        return json
    }

}

extension TransactionPayload: ResponseRepresentable {}
