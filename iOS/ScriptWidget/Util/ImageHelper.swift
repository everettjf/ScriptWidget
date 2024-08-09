//
//  ImageHelper.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/16.
//

import Foundation


class ImageHelper {
    
    static func getItemWidth(widgetSizeType: Int) -> CGFloat {
        var value: CGFloat = 0
        
        switch (widgetSizeType) {
        case 0: value = WidgetSizeHelper.small().width
        case 1: value = WidgetSizeHelper.medium().width
        case 2: value = WidgetSizeHelper.large().width
        default: value = WidgetSizeHelper.small().width
        }
        
        return value
    }
    
    
    static func getItemHeight(widgetSizeType: Int) -> CGFloat {
        var value: CGFloat = 0
        
        switch (widgetSizeType) {
        case 0: value = WidgetSizeHelper.small().height
        case 1: value = WidgetSizeHelper.medium().height
        case 2: value = WidgetSizeHelper.large().height
        default: value = WidgetSizeHelper.small().height
        }
        
        return value
    }
    
}
