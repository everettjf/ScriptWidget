//
//  AppDelegate.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/10/10.
//

import Foundation
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        let _ = globalState.screenBounds
        
        sharedStoreManager.start()
        
        #if !DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            AppHelper.requestReview()
        }
        #endif
        
        return true
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        
    }
    
}
