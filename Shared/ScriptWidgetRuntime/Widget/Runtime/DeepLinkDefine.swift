//
//  DeepLinkDefine.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/4/12.
//

import Foundation


let kDeepLinkDefaultScheme : String = "widget-deeplink"
let kDeepLinkDefaultURL : URL = URL(string: "widget-deeplink://default")!
// Reserved for the system web-auth session, never ordinary link forwarding.
let kSpotifyAuthorizationCallbackScheme = "scriptwidget-spotify-auth"
