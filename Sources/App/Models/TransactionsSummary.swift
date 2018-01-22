//
//  File.swift
//  App
//
//  Created by Attila Nemet on 22/01/2018.
//

import Vapor

final class TransactionsSummary {

    static let sumAmountKey = "sumAmount"

    let sumAmount: Double

    init(sumAmount: Double) {
        self.sumAmount = sumAmount
    }

}

extension TransactionsSummary: JSONConvertible {

    convenience init(json: JSON) throws {
        try self.init(sumAmount: json.get(TransactionsSummary.sumAmountKey))
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(TransactionsSummary.sumAmountKey, sumAmount)
        return json
    }

}

extension TransactionsSummary: ResponseRepresentable {}
