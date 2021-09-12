//
//  IntentHandler.swift
//  ScriptWidgetIntent
//
//  Created by everettjf on 2020/10/7.
//

import Intents

class IntentHandler: INExtension, ScriptIntentHandling {
    
    override func handler(for intent: INIntent) -> Any {
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.
        
        return self
    }
    
    
    func provideScriptOptionsCollection(for intent: ScriptIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        
        let items = sharedScriptManager.listScripts()
        let scripts = items.map { $0.name }
        let collection = INObjectCollection<NSString>(items: scripts.map { $0 as NSString } )
        completion(collection,nil)
    }
}
