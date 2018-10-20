enum StarlingAPI: String {
    static let baseURL = "https://api.starlingbank.com/api/v1/"

    case getTransactions = "transactions"

    var uri: String {
        return StarlingAPI.baseURL + rawValue
    }
}

enum StarlingParameters: String {
    case from
    case to
}
