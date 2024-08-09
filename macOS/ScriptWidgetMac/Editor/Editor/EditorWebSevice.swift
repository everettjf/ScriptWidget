//
//  EditorWebSevice.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/1/15.
//

import Foundation
import Vapor

let kEditorWebServiceHost = "127.0.0.1"
let kEditorWebServicePort = 23355

func editorWebServiceUrl() -> String {
    var editorName = ""
    if MacKitUtil.isSystemThemeDark() {
        editorName = "editor-dark.html"
    } else {
        editorName = "editor-light.html"
    }
    return "http://\(kEditorWebServiceHost):\(kEditorWebServicePort)/\(editorName)"
}

func editorWebServiceRoutes(_ app: Application) throws {
    app.get("") { req in
        return "ScriptWidget Editor Service"
    }
}

// configures your application
public func editorWebServiceAppConfigure(_ app: Application) throws {
    // port
    app.http.server.configuration.hostname = kEditorWebServiceHost
    app.http.server.configuration.port = kEditorWebServicePort
    
    // serve static files
    let resourceDir = Bundle.main.url(forResource: "Editor", withExtension: "bundle")
    if let staticDir = resourceDir?.appendingPathComponent("static") {
        print("static dir = \(staticDir.path)")
        app.middleware.use(FileMiddleware(publicDirectory: staticDir.path))
    }

    // register routes
    try editorWebServiceRoutes(app)
}

func internalRunWebService() {
    do {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        
        let app = Application(env)
        defer { app.shutdown() }
        
        try editorWebServiceAppConfigure(app)
        try app.run()
    } catch {
        print("exception \(error)")
    }
}

func runEditorWebService() {
    DispatchQueue.global().async {
        internalRunWebService()
    }
}
