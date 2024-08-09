//
//  ScriptLiveActivityManager.swift
//  ScriptWidget
//
//  Created by everettjf on 2022/9/25.
//

import Foundation
import ActivityKit


class ScriptLiveActivityManager {
    
    func create(scriptName: String, scriptParameter: String) {
        if #available(iOS 16.1, *) {
            let initialContentState = ScriptLiveActivityAttributes.ScriptLiveActivityState(scriptState: "")
            let activityAttributes = ScriptLiveActivityAttributes(scriptName: scriptName, scriptParameter: scriptParameter)
            
            do {
                let deliveryActivity = try Activity.request(attributes: activityAttributes, contentState: initialContentState)
                print("Requested Live Activity \(String(describing: deliveryActivity.id)).")
            } catch (let error) {
                print("Error requesting Live Activity \(error.localizedDescription).")
            }
        }
    }
    
    
}



let sharedLiveActivityManager = ScriptLiveActivityManager()
