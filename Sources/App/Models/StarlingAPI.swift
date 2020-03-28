import Vapor

enum StarlingAPI {
    static let baseURL = "https://api.starlingbank.com/api/v2/"

    case getBalance(accountUid: UUID)
    case getTransactions(accountUid: UUID, categoryUid: UUID)

    private var path: String {
        switch self {
        case .getBalance(let accountUid):
            return "accounts/\(accountUid)/balance"
        case let .getTransactions(accountUid, categoryUid):
            return "feed/account/\(accountUid)/category/\(categoryUid)"
        }
    }

    var uri: URI {
        URI(string: StarlingAPI.baseURL + path)
    }
}

struct StarlingParameters: Content {
    var changesSince: String?
}
