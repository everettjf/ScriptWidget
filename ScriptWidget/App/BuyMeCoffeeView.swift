//
//  BuyMeCoffee.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/26.
//

import SwiftUI
import SwiftyStoreKit
import StoreKit

class BuyMeCoffeeDataObject : ObservableObject {
    
    @Published var loading = true
    @Published var coffeeTitle = ""
    @Published var coffeePrice = ""
    @Published var coffeeDescription = ""
    @Published var fetchCoffeeError = ""
    @Published var alreadyPurchased = false
    @Published var purchasing = false
    
    @Published var alertInfo = ""
    @Published var showAlertInfo = false
    
    var currentProduct: SKProduct? = nil
    
    init(loading: Bool) {
        self.loading = false
        self.coffeeTitle = "Buy me a coffee"
        self.coffeeDescription = "Buy me a coffee will unlock future features"
        self.coffeePrice = "$1.99"
//        self.fetchCoffeeError = "skldjflsjfdljsldfjs"
        self.alreadyPurchased = true
        self.purchasing = true
    }
    
    init() {
        
    }
    
    func request() {
        self.alreadyPurchased = sharedStoreManager.hadCoffee()
        
        SwiftyStoreKit.retrieveProductsInfo(["coffee"]) { result in
            
            self.loading = false
            
            if let product = result.retrievedProducts.first {
                
                self.currentProduct = product
                
                self.coffeePrice = product.localizedPrice!
                self.coffeeTitle = product.localizedTitle
                self.coffeeDescription = product.localizedDescription
                
                print("Product Title: \(self.coffeeTitle)")
                print("Product Description: \(self.coffeeDescription)")
                print("Product Price: \(self.coffeePrice)")
                
            }
            else if let invalidProductId = result.invalidProductIDs.first {
                self.fetchCoffeeError = "Invalid product identifier: \(invalidProductId)"
                print(self.fetchCoffeeError)
            }
            else {
                self.fetchCoffeeError = "Error: \(String(describing: result.error))"
                print(self.fetchCoffeeError)
            }
        }
        
    }
    
    
    func purchase() {
        if self.alreadyPurchased {
            return
        }
        
        if self.purchasing {
            return
        }
        
        self.purchasing = true
        SwiftyStoreKit.purchaseProduct("coffee", quantity: 1, atomically: true) { result in
            self.purchasing = false
            
            switch result {
            case .success(let purchase):
                print("Purchase Success: \(purchase.productId)")
                
                UserDefaults.standard.setValue("emmmmm", forKey: "emmmmmm..mmm")
                
                self.alreadyPurchased = true
                
            case .error(let error):
                
                var errorInfo = ""
                
                switch error.code {
                case .unknown: errorInfo = ("Unknown error. Please contact support")
                case .clientInvalid: errorInfo = ("Not allowed to make the payment")
                case .paymentCancelled: break
                case .paymentInvalid: errorInfo = ("The purchase identifier was invalid")
                case .paymentNotAllowed: errorInfo = ("The device is not allowed to make the payment")
                case .storeProductNotAvailable: errorInfo = ("The product is not available in the current storefront")
                case .cloudServicePermissionDenied: errorInfo = ("Access to cloud service information is not allowed")
                case .cloudServiceNetworkConnectionFailed: errorInfo = ("Could not connect to the network")
                case .cloudServiceRevoked: errorInfo = ("User has revoked permission to use this cloud service")
                default: errorInfo = ((error as NSError).localizedDescription)
                }
                
                self.alertInfo = errorInfo
                self.showAlertInfo = true
            }
        }
        
    }
    
    
    func restore() {
        if self.alreadyPurchased {
            return
        }
        
        if self.purchasing {
            return
        }
        
        self.purchasing = true
        SwiftyStoreKit.restorePurchases(atomically: true) { results in
            self.purchasing = false
            
            if results.restoreFailedPurchases.count > 0 {
                self.alertInfo = "Restore Failed: \(results.restoreFailedPurchases)"
                self.showAlertInfo = true
            }
            else if results.restoredPurchases.count > 0 {
                print("Restore Success: \(results.restoredPurchases)")
                
                for item in results.restoredPurchases {
                    if item.productId == "coffee" {
                        UserDefaults.standard.setValue("emmmmm", forKey: "emmmmmm..mmm")
                        self.alreadyPurchased = true
                        
                        self.alertInfo = "Succeed"
                        self.showAlertInfo = true
                        break
                    }
                }
            }
            else {
                self.alertInfo = "Nothing to Restore"
                self.showAlertInfo = true
            }
        }
    }
}

struct BuyMeCoffeeView: View {
    
    @ObservedObject var dataObject = BuyMeCoffeeDataObject()
    
    
    var body: some View {
        VStack(spacing: 10) {
            if dataObject.loading {
                ProgressView()
            } else {
                
                Image(systemName: "wand.and.stars.inverse")
                    .font(.system(size: 100, weight: .bold, design: .monospaced))
                    .gradientForegroundColors(colors:[Color.orange, Color.red])
                    .padding()
                
                if dataObject.fetchCoffeeError.isEmpty {
                    Text(dataObject.coffeeTitle)
                        .font(.title)
                    
                    Text(dataObject.coffeePrice)
                        .font(.title)
                    
                    Text(dataObject.coffeeDescription)
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                } else {
                    Text(dataObject.fetchCoffeeError)
                        .font(.headline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.leading)
                }
                
                if dataObject.alreadyPurchased {
                    Text("[ Already Purchased ]")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                if dataObject.purchasing {
                    ProgressView()
                }
                
                Button(action: {
                    self.dataObject.purchase()
                }) {
                    HStack {
                        Image(systemName: "wand.and.stars.inverse")
                            .font(.title)
                        Text(dataObject.alreadyPurchased ? "Thank you :)" : "Buy me a coffee")
                            .fontWeight(.semibold)
                            .font(.title)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding()
                    .foregroundColor(.white)
                    .background(LinearGradient(gradient: Gradient(colors: [Color.orange, Color.red]), startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(40)
                    .padding(.horizontal, 20)
                }
                .padding()
                
                if !dataObject.alreadyPurchased {
                    Button(action: {
                        dataObject.restore()
                        
                    }) {
                        Text("Restore")
                            .font(.headline)
                    }
                }
                    
            }
            
        }
        .onAppear {
            dataObject.request()
        }
        .navigationBarTitle(Text("BuyMeCoffee"), displayMode: .inline)
        .alert(isPresented: $dataObject.showAlertInfo) {
            Alert(title: Text(""), message: Text(dataObject.alertInfo), dismissButton: .default(Text("OK")))
        }
        
    }
}

struct BuyMeCoffeeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BuyMeCoffeeView(dataObject: BuyMeCoffeeDataObject(loading: false))
                .preferredColorScheme(.light)
            BuyMeCoffeeView(dataObject: BuyMeCoffeeDataObject(loading: false))
                .preferredColorScheme(.dark)
        }
    }
}
