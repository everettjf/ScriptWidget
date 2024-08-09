//
//  MineColor.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/10.
//
import Foundation
import SwiftUI

let gradientColorsData: [[Color]] = [
    [Color("ColorBlueberryLight"), Color("ColorBlueberryDark")],
    [Color("ColorStrawberryLight"), Color("ColorStrawberryDark")],
    [Color("ColorLemonLight"), Color("ColorLemonDark")],
    [Color("ColorPlumLight"), Color("ColorPlumDark")],
    [Color("ColorLimeLight"), Color("ColorLimeDark")],
    [Color("ColorPomegranateLight"), Color("ColorPomegranateDark")],
    [Color("ColorPearLight"), Color("ColorPearDark")],
    [Color("ColorGooseberryLight"), Color("ColorGooseberryDark")],
    [Color("ColorMangoLight"), Color("ColorMangoDark")],
    [Color("ColorWatermelonLight"), Color("ColorWatermelonDark")],
    [Color("ColorCherryLight"), Color("ColorCherryDark")],
    [Color("ColorGrapefruitLight"), Color("ColorGrapefruitDark")],
    [Color("ColorAppleLight"), Color("ColorAppleDark")],
]

func getGradientColorsWithString(string: String) -> [Color] {
    let arr = Array(string)
    if arr.count >= 2 {
        let first = arr[0].asciiValue ?? 0
        let second = arr[1].asciiValue ?? 0
        let sum = Int(first + second)
        let count = gradientColorsData.count
        return gradientColorsData[sum % count]
    }
    
    return gradientColorsData[0]
}
