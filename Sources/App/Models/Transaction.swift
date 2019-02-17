import Vapor
import FluentPostgreSQL

struct TransactionResponse: Content {

    let id: UUID?
    let amount: Double
    let direction: TransactionDirection
    let created: Date
    let narrative: String
    let source: TransactionSource

}

enum TransactionDirection: String, Content, ReflectionDecodable {
    static func reflectDecoded() throws -> (TransactionDirection, TransactionDirection) {
        return (.none, .outbound)
    }

    case none = "NONE"
    case outbound = "OUTBOUND"
    case inbound = "INBOUND"

}

enum TransactionSource: String, Equatable, Content, ReflectionDecodable {
    static func reflectDecoded() throws -> (TransactionSource, TransactionSource) {
        return (.directCredit, .directDebit)
    }

    case directCredit = "DIRECT_CREDIT"
    case directDebit = "DIRECT_DEBIT"
    case directDebitDispute = "DIRECT_DEBIT_DISPUTE"
    case internalTransfer = "INTERNAL_TRANSFER"
    case masterCard = "MASTER_CARD"
    case fasterPaymentsIn = "FASTER_PAYMENTS_IN"
    case fasterPaymentsOut = "FASTER_PAYMENTS_OUT"
    case fasterPaymentsReversal = "FASTER_PAYMENTS_REVERSAL"
    case stripeFunding = "STRIPE_FUNDING"
    case interestPayment = "INTEREST_PAYMENT"
    case nostroDeposit = "NOSTRO_DEPOSIT"
    case overdraft = "OVERDRAFT"
    case settleUp = "SETTLE_UP"
    case externalRegularInbound = "EXTERNAL_REGULAR_INBOUND"
    case externalRegularOutbound = "EXTERNAL_REGULAR_OUTBOUND"
    case externalInbound = "EXTERNAL_INBOUND"
    case externalOutbound = "EXTERNAL_OUTBOUND"

    var isExternal: Bool {
        switch self {
        case .externalInbound,
             .externalOutbound,
             .externalRegularInbound,
             .externalRegularOutbound:
            return true
        default:
            return false
        }
    }

}

final class Transaction: PostgreSQLUUIDModel {

    private enum CodingKeys: String, CodingKey {
        case id
        case amount
        case direction
        case created
        case narrative
        case source
        case isArchived = "is_archived"
        case internalNarrative = "internal_narrative"
        case internalAmount = "internal_amount"
        case userID = "user_id"
    }

    static let entity = "transactions"

    var id: UUID?
    var amount: Double
    var direction: TransactionDirection
    var created: Date
    var narrative: String
    var source: TransactionSource

    let isArchived: Bool
    let internalNarrative: String?
    let internalAmount: Double?

    var userID: User.ID

    var user: Parent<Transaction, User> {
        return parent(\.userID)
    }

    var response: TransactionResponse {
        return TransactionResponse(id: id,
                                   amount: amount,
                                   direction: direction,
                                   created: created,
                                   narrative: narrative,
                                   source: source)
    }

    init(id: UUID? = nil,
         amount: Double,
         direction: TransactionDirection,
         created: Date,
         narrative: String,
         source: TransactionSource,
         isArchived: Bool,
         internalNarrative: String?,
         internalAmount: Double?,
         userID: User.ID) {
        self.id = id
        self.amount = amount
        self.direction = direction
        self.created = created
        self.narrative = narrative
        self.source = source
        self.isArchived = isArchived
        self.internalNarrative = internalNarrative
        self.internalAmount = internalAmount
        self.userID = userID
    }

    init(from: StarlingTransaction) {
        self.id = from.id
        self.amount = from.amount
        self.direction = from.direction
        self.created = from.created
        self.narrative = from.narrative
        self.source = from.source ?? .fasterPaymentsOut
        self.isArchived = false
        self.internalNarrative = nil
        self.internalAmount = nil
        self.userID = UUID()
    }

}

extension Transaction: Migration {}
extension Transaction: Content {}
extension Transaction: Parameter {}
