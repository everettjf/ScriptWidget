//
//  StoreManager.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/26.
//

import Foundation
import SwiftyStoreKit


class StoreManager {
    
    
    func start() {
        
        SwiftyStoreKit.completeTransactions(atomically: true) { purchases in
            for purchase in purchases {
                switch purchase.transaction.transactionState {
                case .purchased, .restored:
                    if purchase.needsFinishTransaction {
                        // Deliver content from server, then:
                        SwiftyStoreKit.finishTransaction(purchase.transaction)
                    }
                // Unlock content
                case .failed, .purchasing, .deferred:
                    break // do nothing
                default:
                    break
                }
            }
        }
        
        
    }
    
    func hadCoffee() -> Bool {
        if let purchaseKey = UserDefaults.standard.string(forKey: "emmmmmm..mmm") {
            return (purchaseKey == "emmmmm")
        }
        return false
    }
}

let sharedStoreManager = StoreManager()
