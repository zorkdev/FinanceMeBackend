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

    enum Status: String, Codable {
        case accountCheck = "ACCOUNT_CHECK"
        case declined = "DECLINED"
        case pending = "PENDING"
        case refunded = "REFUNDED"
        case retrying = "RETRYING"
        case reversed = "REVERSED"
        case settled = "SETTLED"
        case upcoming = "UPCOMING"
    }

    let feedItemUid: UUID
    let amount: StarlingAmount
    let direction: Direction
    let transactionTime: Date
    let source: TransactionSource?
    let counterPartyType: CounterPartyType?
    let counterPartyName: String
    let reference: String?
    let status: Status

    var narrative: String {
        switch counterPartyType {
        case .payee?: return reference ?? counterPartyName
        default: return counterPartyName
        }
    }

    var signedAmount: Double {
        return direction == .out ? -amount.doubleValue : amount.doubleValue
    }

    var isStatusValid: Bool {
        switch status {
        case .pending, .refunded, .settled: return true
        case .accountCheck, .declined, .retrying, .reversed, .upcoming: return false
        }
    }
}
