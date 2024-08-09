//
//  PreviewWidgetSize.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/1/15.
//

import Foundation


class PreviewWidgetSize {
    static let small: CGSize = .init(width: 169, height: 169)
    static let medium: CGSize = .init(width: 360, height: 169)
    static let large: CGSize = .init(width: 360, height: 376)
    
    static func size(_ size: Int) -> CGSize {
        switch size {
        case 0: return small
        case 1: return medium
        case 2: return large
        default: return small
        }
    }
}
