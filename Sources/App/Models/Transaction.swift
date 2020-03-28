import Vapor
import Fluent

struct TransactionResponse: Content {
    let id: UUID?
    let amount: Double
    let direction: TransactionDirection
    let created: Date
    let narrative: String
    let source: TransactionSource
}

enum TransactionDirection: String, Codable {
    case none = "NONE"
    case outbound = "OUTBOUND"
    case inbound = "INBOUND"
}

enum TransactionSource: String, Equatable, Codable {
    case cashDeposit = "CASH_DEPOSIT"
    case cashDepositCharge = "CASH_DEPOSIT_CHARGE"
    case cashWithdrawal = "CASH_WITHDRAWAL"
    case cashWithdrawalCharge = "CASH_WITHDRAWAL_CHARGE"
    case chaps = "CHAPS"
    case cheque = "CHEQUE"
    case cicsCheque = "CICS_CHEQUE"
    case currencyCloud = "CURRENCY_CLOUD"
    case directCredit = "DIRECT_CREDIT"
    case directDebit = "DIRECT_DEBIT"
    case directDebitDispute = "DIRECT_DEBIT_DISPUTE"
    case fasterPaymentsIn = "FASTER_PAYMENTS_IN"
    case fasterPaymentsOut = "FASTER_PAYMENTS_OUT"
    case fasterPaymentsRefund = "FASTER_PAYMENTS_REFUND"
    case fasterPaymentsReversal = "FASTER_PAYMENTS_REVERSAL"
    case fxTransfer = "FX_TRANSFER"
    case interestPayment = "INTEREST_PAYMENT"
    case internalTransfer = "INTERNAL_TRANSFER"
    case issPayment = "ISS_PAYMENT"
    case loanLatePayment = "LOAN_LATE_PAYMENT"
    case loanOverpayment = "LOAN_OVERPAYMENT"
    case loanPrincipalPayment = "LOAN_PRINCIPAL_PAYMENT"
    case loanRepayment = "LOAN_REPAYMENT"
    case masterCard = "MASTER_CARD"
    case mastercardChargeback = "MASTERCARD_CHARGEBACK"
    case mastercardMoneysend = "MASTERCARD_MONEYSEND"
    case nearbyPayment = "NEARBY_PAYMENT"
    case nostroDeposit = "NOSTRO_DEPOSIT"
    case onUsPayMe = "ON_US_PAY_ME"
    case overdraft = "OVERDRAFT"
    case overdraftInterestWaived = "OVERDRAFT_INTEREST_WAIVED"
    case sepaCreditTransfer = "SEPA_CREDIT_TRANSFER"
    case sepaDirectDebit = "SEPA_DIRECT_DEBIT"
    case settleUp = "SETTLE_UP"
    case starlingPayment = "STARLING_PAYMENT"
    case starlingPayStripe = "STARLING_PAY_STRIPE"
    case stripeFunding = "STRIPE_FUNDING"
    case subscriptionCharge = "SUBSCRIPTION_CHARGE"
    case target2CustomerPayment = "TARGET2_CUSTOMER_PAYMENT"

    case externalRegularInbound = "EXTERNAL_REGULAR_INBOUND"
    case externalRegularOutbound = "EXTERNAL_REGULAR_OUTBOUND"
    case externalInbound = "EXTERNAL_INBOUND"
    case externalOutbound = "EXTERNAL_OUTBOUND"
    case externalSavings = "EXTERNAL_SAVINGS"

    var isExternal: Bool {
        switch self {
        case .externalInbound,
             .externalOutbound,
             .externalRegularInbound,
             .externalRegularOutbound,
             .externalSavings:
            return true
        default:
            return false
        }
    }
}

extension FieldKey {
    static var amount: Self { "amount" }
    static var direction: Self { "direction" }
    static var created: Self { "created" }
    static var narrative: Self { "narrative" }
    static var source: Self { "source" }
    static var isArchived: Self { "is_archived" }
    static var internalNarrative: Self { "internal_narrative" }
    static var internalAmount: Self { "internal_amount" }
}

final class Transaction: Model, Content {
    static let schema = "transactions"

    @ID()
    var id: UUID?

    @Field(key: .amount)
    var amount: Double

    @Field(key: .direction)
    var direction: TransactionDirection

    @Field(key: .created)
    var created: Date

    @Field(key: .narrative)
    var narrative: String

    @Field(key: .source)
    var source: TransactionSource

    @Field(key: .isArchived)
    var isArchived: Bool

    @OptionalField(key: .internalNarrative)
    var internalNarrative: String?

    @OptionalField(key: .internalAmount)
    var internalAmount: Double?

    @Parent(key: .userID)
    var user: User

    var response: TransactionResponse {
        TransactionResponse(id: id,
                            amount: amount,
                            direction: direction,
                            created: created,
                            narrative: narrative,
                            source: source)
    }

    init() {}

    init(id: UUID? = nil,
         amount: Double,
         direction: TransactionDirection,
         created: Date,
         narrative: String,
         source: TransactionSource,
         isArchived: Bool,
         internalNarrative: String?,
         internalAmount: Double?,
         userID: User.IDValue) {
        self.id = id
        self.amount = amount
        self.direction = direction
        self.created = created
        self.narrative = narrative
        self.source = source
        self.isArchived = isArchived
        self.internalNarrative = internalNarrative
        self.internalAmount = internalAmount
        self.$user.id = userID
    }

    init?(from: StarlingTransaction) {
        guard from.isStatusValid else { return nil }
        self.id = from.feedItemUid
        self.amount = from.signedAmount
        self.direction = from.direction.direction
        self.created = from.transactionTime
        self.narrative = from.narrative
        self.source = from.source ?? .fasterPaymentsOut
        self.isArchived = false
        self.internalNarrative = nil
        self.internalAmount = nil
        self.$user.id = User.IDValue()
    }
}

struct CreateTransaction: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Transaction.schema)
            .id()
            .field(.amount, .double, .required)
            .field(.direction, .string, .required)
            .field(.created, .datetime, .required)
            .field(.narrative, .string, .required)
            .field(.source, .string, .required)
            .field(.isArchived, .bool, .required)
            .field(.internalNarrative, .string)
            .field(.internalAmount, .double)
            .foreignKey(.userID, references: User.schema, .id)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Transaction.schema).delete()
    }
}
