import Vapor

enum StarlingAPI: String {
    static let baseURL = "https://api.starlingbank.com/api/v1/"

    case getBalance = "accounts/balance"
    case getTransactions = "transactions"

    var uri: String {
        return StarlingAPI.baseURL + rawValue
    }
}

struct StarlingParameters: Content {

    var from: String?
    var to: String?

}
