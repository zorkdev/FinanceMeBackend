//
//  StarlingAPI.swift
//  App
//
//  Created by Attila Nemet on 23/01/2018.
//

import Foundation

enum StarlingAPI: String {
    static let baseURL = "https://api.starlingbank.com/api/v1/"

    case getBalance = "accounts/balance"
    case getTransactions = "transactions"

    var uri: String {
        return StarlingAPI.baseURL + rawValue
    }
}

enum StarlingParameters: String {
    case from
    case to
}
