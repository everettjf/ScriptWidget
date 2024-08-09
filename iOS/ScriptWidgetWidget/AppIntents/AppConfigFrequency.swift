//
//  AppConfigFrequency.swift
//  ScriptWidgetWidget
//
//  Created by zhufeng on 2023/10/7.
//

import Foundation
import AppIntents

enum AppConfigFrequency: String, AppEnum {
    case minutes_1
    case minutes_10
    case minutes_30
    case hours_1
    case hours_3
    case hours_6
    case hours_12
    case day_1

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "FrequencyType")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .minutes_1: "1 Minute",
        .minutes_10: "10 Minutes",
        .minutes_30: "30 Minutes",
        .hours_1: "1 Hour",
        .hours_3: "3 Hours",
        .hours_6: "6 Hours",
        .hours_12: "12 Hours",
        .day_1: "1 Day"
    ]
}

