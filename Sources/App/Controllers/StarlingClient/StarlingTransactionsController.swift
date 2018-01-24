//
//  StarlingTransactionsController.swift
//  App
//
//  Created by Attila Nemet on 23/01/2018.
//

import Vapor

final class StarlingTransactionsController {

    func getTransactions(user: User, from: Date? = nil, to: Date? = nil) throws -> [Transaction] {
        guard let token = user.sToken else {
            throw Abort.serverError
        }

        var parameters = [String: NodeRepresentable]()

        if let from = from {
            parameters[StarlingParameters.from.rawValue] = from
        }

        if let to = to {
            parameters[StarlingParameters.to.rawValue] = to
        }

        let response = try StarlingClientController.shared.performRequest(method: .get,
                                                                          endpoint: .getTransactions,
                                                                          token: token,
                                                                          parameters: parameters)

        guard let json = response.json,
            let halResponse = json["_embedded"],
            let transactionsList = halResponse["transactions"],
            let transactionsArray = transactionsList.array else {
            throw Abort.serverError
        }

        var transactions = [Transaction]()

        for item in transactionsArray {
            let transaction = try Transaction(json: item)
            transactions.append(transaction)
        }

        return transactions
    }

}
