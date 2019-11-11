import Vapor

struct StarlingTransactionList: Content {
    let feedItems: [StarlingTransaction]
}

struct StarlingTransaction: Content {
    enum Direction: String, Codable {
        case `in` = "IN"
        case out = "OUT"

        var direction: TransactionDirection {
            switch self {
            case .in: return .inbound
            case .out: return .outbound
            }
        }
    }

    enum CounterPartyType: String, Codable {
        case category = "CATEGORY"
        case cheque = "CHEQUE"
        case customer = "CUSTOMER"
        case payee = "PAYEE"
        case merchant = "MERCHANT"
        case sender = "SENDER"
        case starling = "STARLING"
        case loan = "LOAN"
    }

    let feedItemUid: UUID
    let amount: StarlingAmount
    let direction: Direction
    let transactionTime: Date
    let source: TransactionSource?
    let counterPartyType: CounterPartyType?
    let counterPartyName: String
    let reference: String?

    var narrative: String {
        switch counterPartyType {
        case .payee?: return reference ?? counterPartyName
        default: return counterPartyName
        }
    }

    var signedAmount: Double {
        return direction == .out ? -amount.doubleValue : amount.doubleValue
    }
}
