/**
 *  SimpleStore
 *
 *  Copyright (c) 2017 Mahmud Ahsan. Licensed under the MIT license, as follows:
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in all
 *  copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 *  SOFTWARE.
 */

import Foundation
import SwiftyStoreKit

public struct Product{
    public let name:String
    public let productId: String
    public var price:String
    public var purchased:Bool
    public let image: String
    
    public init(name:String, productId: String, price: String, purchased: Bool, image: String){
        self.name = name
        self.productId = productId
        self.price = price
        self.purchased = purchased
        self.image = image
    }
}

@objc public protocol StoreManagerDelegate{
    func showHud()
    func hideHud()
    func purchaseSuccess(productId:String)
    func failPurchase(message:String)
    func successPurchase(message:String)
}

open class StoreManager {
    public static var shared = StoreManager()
    private init(){}
    private let userDefaults:UserDefaults = UserDefaults()
    public var storeManagerDelegate:StoreManagerDelegate?
    
    public static let RestoreAll = "restoreAll"
    public var storeItems  = [Product]()
    
    public func completeTransactionAtAppLaunch(){
        SwiftyStoreKit.completeTransactions(atomically: true) { purchases in
            for purchase in purchases {
                if purchase.transaction.transactionState == .purchased || purchase.transaction.transactionState == .restored {
                    if purchase.needsFinishTransaction {
                        // Deliver content from server, then:
                        SwiftyStoreKit.finishTransaction(purchase.transaction)
                    }
                    print("purchased: \(purchase)")
                }
            }
        }
    }
    
    public func loadStoreProducts(){
        var productIds = Set<String>()
        for item in storeItems {
            if item.productId != StoreManager.RestoreAll {
                productIds.insert(item.productId)
            }
        }
        
        retrieveProductInfo(productIds: productIds)
    }
    
    public func purchaseProduct(id: String){
        storeManagerDelegate?.showHud()
        SwiftyStoreKit.purchaseProduct(id, quantity: 1, atomically: true) { result in
            self.storeManagerDelegate?.hideHud()
            switch result {
            case .success(let purchase):
                self.storeManagerDelegate?.successPurchase(message:"购买成功!")
                print("Purchase Success: \(purchase.productId)")
                self.postProductPurchase(purchase.productId)
            case .error(let error):
                switch error.code {
                case .unknown: print("Unknown error. Please contact support")
                case .clientInvalid: print("Not allowed to make the payment")
                case .paymentCancelled: break
                case .paymentInvalid: print("The purchase identifier was invalid")
                case .paymentNotAllowed: print("The device is not allowed to make the payment")
                case .storeProductNotAvailable: print("The product is not available in the current storefront")
                case .cloudServicePermissionDenied: print("Access to cloud service information is not allowed")
                case .cloudServiceNetworkConnectionFailed: print("Could not connect to the network")
                case .cloudServiceRevoked: print("User has revoked permission to use this cloud service")
                case .privacyAcknowledgementRequired, .unauthorizedRequestData, .invalidOfferIdentifier
                , .invalidSignature, .missingOfferParams, .invalidOfferPrice:
                    print("error: \(error.code)")
                }
                
                switch error.code {
                case .unknown: self.storeManagerDelegate?.failPurchase(message: "Unknown error. Please contact support")
                case .clientInvalid: self.storeManagerDelegate?.failPurchase(message: "Not allowed to make the payment")
                case .paymentCancelled: break
                case .paymentInvalid: self.storeManagerDelegate?.failPurchase(message: "The purchase identifier was invalid")
                case .paymentNotAllowed: self.storeManagerDelegate?.failPurchase(message: "The device is not allowed to make the payment")
                case .storeProductNotAvailable: self.storeManagerDelegate?.failPurchase(message: "The product is not available in the current storefront")
                case .cloudServicePermissionDenied: self.storeManagerDelegate?.failPurchase(message: "Access to cloud service information is not allowed")
                case .cloudServiceNetworkConnectionFailed: self.storeManagerDelegate?.failPurchase(message: "Could not connect to the network")
                case .cloudServiceRevoked: self.storeManagerDelegate?.failPurchase(message: "User has revoked permission to use this cloud service")
                case .privacyAcknowledgementRequired, .unauthorizedRequestData, .invalidOfferIdentifier
                    , .invalidSignature, .missingOfferParams, .invalidOfferPrice:
                    self.storeManagerDelegate?.failPurchase(message: "error: \(error.code)")
                @unknown default:
                    self.storeManagerDelegate?.failPurchase(message: "error: \(error.code)")
                }
                
            }
        }
    }
    
    public func restoreProducts(){
        storeManagerDelegate?.showHud()
        SwiftyStoreKit.restorePurchases(atomically: true) { results in
            self.storeManagerDelegate?.hideHud()
            if results.restoreFailedPurchases.count > 0 {
                self.storeManagerDelegate?.failPurchase(message: "恢复内购失败! 原因:\(results.restoreFailedPurchases)")
                print("Restore Failed: \(results.restoreFailedPurchases)")
            }
            else if results.restoredPurchases.count > 0 {
                self.storeManagerDelegate?.successPurchase(message: "恢复内购成功!")
                print("Restore Success: \(results.restoredPurchases)")
                for purchase in results.restoredPurchases {
                    self.postProductPurchase(purchase.productId)
                }
            }
            else {
                self.storeManagerDelegate?.successPurchase(message: "没有需要恢复的内购项目.")
                print("Nothing to Restore")
            }
        }
    }
    
    public func shouldAddStorePaymentHandling(_ canDeliver: Bool){
        SwiftyStoreKit.shouldAddStorePaymentHandler = { payment, product in
            return canDeliver
            // return true if the content can be delivered by your app
            // return false otherwise
        }
    }
    
    public func isProductPurchased(_ productId: String) -> Bool {
        let purchase = userDefaults.value(forKey: productId) as? Bool
        return purchase ?? false
    }
    
    private func retrieveProductInfo(productIds: Set<String>){
        SwiftyStoreKit.retrieveProductsInfo(productIds) { result in
            result.retrievedProducts.forEach({ (product) in
                let priceString = product.localizedPrice!
                print("Product: \(product.localizedDescription), price: \(priceString)")
                self.updateProductPrice(productId: product.productIdentifier, price: priceString)
            })
            result.invalidProductIDs.forEach({ (invalidProductId) in
                print("Invalid Product Indentifier: \(invalidProductId)")
            })
            if let e = result.error {
                print("Error: \(String(describing: e))")
            }
        
        }
    }
    
    private func updateProductPrice(productId:String, price:String){
        for (index, item) in storeItems.enumerated() {
            if item.productId == productId {
                var copyItem = item
                copyItem.price = price
                storeItems.remove(at: index)
                storeItems.insert(copyItem, at: index)
            }
        }
    }
    
    private func makeProductPurchased(productId: String) {
        userDefaults.setValue(true, forKey: productId)
        userDefaults.synchronize()
    }
    
    private func postProductPurchase(_ productId: String){
        self.makeProductPurchased(productId: productId)
        self.storeManagerDelegate?.purchaseSuccess(productId: productId)
    }
}
