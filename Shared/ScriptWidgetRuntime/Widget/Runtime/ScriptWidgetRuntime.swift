//
//  ScriptWidgetRuntime.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/10/11.
//

import Foundation
import JavaScriptCore
import Combine

enum ScriptWidgetError: Error {
    case undefinedRender(String)
    
    case internalError(String)
    case transformError(String)
    case scriptError(String)
    case scriptException(String)
}

extension JSContext {
    subscript(key: String) -> Any {
        get {
            return self.objectForKeyedSubscript(key)!
        }
        set {
            self.setObject(newValue, forKeyedSubscript: key as NSCopying & NSObjectProtocol)
        }
    }
}

/*
 
 // $dynamic_island is for dynamic island
 // on iPhone 14 Pro/ProMax and iOS16.1+
 // $dynamic_island({
 //     expanded: {
 //         leading: <text>leading</text>,
 //         trailing: <text>trailing</text>,
 //         center: <text>center</text>,
 //         bottom: <text>bottom</text>,
 //     },
 //     compactLeading: <text>compactLeading</text>,
 //     compactTrailing: <text>compactTrailing</text>,
 //     minimal: <text>minimal</text>,
 // });

 */


struct ScriptWidgetDynamicIslandRuntimeElement {
    struct ExpandedElement {
        public let leading: ScriptWidgetRuntimeElement?
        public let trailing: ScriptWidgetRuntimeElement?
        public let center: ScriptWidgetRuntimeElement?
        public let bottom: ScriptWidgetRuntimeElement?
    }
    
    public let expanded: ExpandedElement
    public let compactLeading: ScriptWidgetRuntimeElement
    public let compactTrailing: ScriptWidgetRuntimeElement
    public let minimal: ScriptWidgetRuntimeElement
    
    init(expanded: ExpandedElement, compactLeading: ScriptWidgetRuntimeElement, compactTrailing: ScriptWidgetRuntimeElement, minimal: ScriptWidgetRuntimeElement) {
        self.expanded = expanded
        self.compactLeading = compactLeading
        self.compactTrailing = compactTrailing
        self.minimal = minimal
    }
    
    init(text: String) {
        let textElement = ScriptWidgetRuntimeElement(tagString: "text", props: ["font":"footnote"], children: [text])
        self.expanded = ExpandedElement(leading: nil, trailing: nil, center: textElement, bottom: nil)
        self.compactLeading = textElement
        self.compactTrailing = textElement
        self.minimal = textElement
    }
}

class ScriptWidgetRuntime {
    
    private let runtimeContext = JSContext()!
    
    private var environments : [String:String]
    private var package : ScriptWidgetPackage
    
    init(package: ScriptWidgetPackage, environments: [String:String]) {
        self.package = package
        self.environments = environments
    }
    
    public func setEnvironment(_ key: String, _ value: String) {
        self.environments[key] = value
    }
    
    private func readSupportScript(_ fileName: String) -> String? {
        return ScriptManager.readBundleFile(bundle: "support", fileName: fileName)
    }
    
    private func transform(_ paramJSX: String, wrapMain: Bool, callAsynFunctionName: String = "") -> AnyPublisher<String, ScriptWidgetError> {
        // async/await support
        var JSX = ""
        if wrapMain {
            JSX += "async function $main() { try {"
            JSX += paramJSX
            if !callAsynFunctionName.isEmpty {
                // call function
                JSX += "await \(callAsynFunctionName)();"
            }
            JSX += "} catch(e){ console.error(e); $error(`${e}`) } }"
        } else {
            JSX = paramJSX
        }
        return Future<String, ScriptWidgetError> { promise in
            guard let babelContent = self.readSupportScript("core.js") else {
                promise(.failure(.internalError("Babel file not found")))
                return
            }
            
            let transformContext = JSContext()!
            
            var exceptionInfo: String?
            transformContext.exceptionHandler = { context, exception in
                print("transform exception : \(exception!.toString() ?? "exception is nil")")
                exceptionInfo = exception?.toString()
            }
            transformContext.evaluateScript(babelContent)
            
            transformContext.evaluateScript("""
                        function ScriptWidgetTransform(input) {
                            var output = Babel.transform(input, { presets: ['scriptwidget'] }).code
                            return output
                        }
                    """)
            
            guard let result = transformContext.objectForKeyedSubscript("ScriptWidgetTransform")?
                    .call(withArguments: [JSX]) else {
                promise(.failure(.transformError("Transform result is nil")))
                return
            }
            
            guard let jsOutput = result.toString() else {
                promise(.failure(.transformError("Transform result is not string : \(result)")))
                return
            }
            
            // check javascript exception
            if let exceptionInfo = exceptionInfo {
                promise(.failure(.scriptException(exceptionInfo)))
                return
            }
            
            // success
            promise(.success(jsOutput))
        }
        .eraseToAnyPublisher()
    }
    
    public func getTypeOfValue(_ value: JSValue) -> String {
        guard let caller = self.runtimeContext.objectForKeyedSubscript("$type_of_object") else {
            return ""
        }
        
        guard let result = caller.call(withArguments: [value]) else {
            return ""
        }

        if !result.isString {
            return ""
        }
        
        return result.toString()
    }
}

extension ScriptWidgetRuntime {
    
    func executeJSXSyncForWidget(_ JSX: String) -> (ScriptWidgetRuntimeElement? , ScriptWidgetError?) {
        var resultError: ScriptWidgetError?
        var resultElement: ScriptWidgetRuntimeElement?
        
        let sem = DispatchSemaphore(value: 0)
        var cancellables: [AnyCancellable] = []

        DispatchQueue.global().async {
            
            let cancelable = self.internalExecuteJSXForWidget(JSX)
                .sink { (completion) in
                    switch completion {
                    case .finished:
                        print("script run finished")
                        
                        sem.signal()
                        
                    case .failure(let error):
                        print("failed : \(error)")
                        resultError = error
                        
                        sem.signal()
                    }
                } receiveValue: { (element) in
                    print("-------------------------------------------")
                    print(element)
                    print("]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]")
                    resultElement = element
                }
            cancellables.append(cancelable)
        }
        
        sem.wait()
        
        return (resultElement, resultError)
    }
    
    private func internalExecuteJSXForWidget(_ JSX: String) -> AnyPublisher<ScriptWidgetRuntimeElement, ScriptWidgetError> {
        return transform(JSX, wrapMain: true)
            .flatMap { JavaScript -> AnyPublisher<ScriptWidgetRuntimeElement, ScriptWidgetError> in
                print("[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[")
                print(JavaScript)

                return self.internalExecuteJavaScriptForWidget(JavaScript)
            }
            .eraseToAnyPublisher()
    }
    
    /*
     load JavaScript and call render()

     const render = () => {
         return (
             <text>Hello SwiftWidget</text>
         )
     }
     */
    private func internalExecuteJavaScriptForWidget(_ JavaScript: String) -> AnyPublisher<ScriptWidgetRuntimeElement, ScriptWidgetError> {
        return Future<ScriptWidgetRuntimeElement, ScriptWidgetError> { promise in
            guard let supportJS = self.readSupportScript("util.js") else {
                promise(.failure(.internalError("scriptwidget not found")))
                return
            }
                        
            // Inject ScriptWidgetRuntime JavaScript Object
            self.runtimeContext["Promise"] = ScriptWidgetRuntimePromise.self
            self.runtimeContext["fetch"] = unsafeBitCast(custom_fetch, to: JSValue.self)
            self.runtimeContext["$fetch"] = unsafeBitCast(custom_fetch, to: JSValue.self)

            self.runtimeContext["$console"] = ScriptWidgetRuntimeConsole.self
            self.runtimeContext["console"] = ScriptWidgetRuntimeConsole.self
            
            self.runtimeContext["$element"] = ScriptWidgetRuntimeElement.self
            self.runtimeContext["$device"] = ScriptWidgetRuntimeDevice.self
            self.runtimeContext["$http"] = ScriptWidgetRuntimeHttp.self
            self.runtimeContext["$file"] = ScriptWidgetRuntimeFile.self

            let custom_getenv:@convention(block) (String)-> String = { [weak self] (key) in
                if let value = self?.environments[key] {
                    return value
                }
                return ""
            }
            self.runtimeContext["$getenv"] = unsafeBitCast(custom_getenv, to: JSValue.self)
            
            let semaphore = DispatchSemaphore(value: 0)
            var resultElement: ScriptWidgetRuntimeElement?
            
            let renderWidget:@convention(block) (ScriptWidgetRuntimeElement)->Void = { rootElement in
                print("root element = \(rootElement)")
                resultElement = rootElement
                semaphore.signal()
            }
            self.runtimeContext["$render"] = unsafeBitCast(renderWidget, to: JSValue.self)
            
            // ignore for dynamic island
            // -begin
            let renderDynamicIsland:@convention(block) (NSDictionary)->Void = { islandInfo in
                print("not support in normal widget rendering : islandInfo = \(islandInfo)")
                semaphore.signal()
            }
            self.runtimeContext["$dynamic_island"] = unsafeBitCast(renderDynamicIsland, to: JSValue.self)
            // -end
            
            let componentDefine:@convention(block) (String, JSValue) -> Void = { [weak self](name, builder) in
                print("define component : \(name) , \(type(of: builder))")
                
                if let type = self?.getTypeOfValue(builder) {
                    print("builder type = \(type)")
                }
            }
            self.runtimeContext["$component"] = unsafeBitCast(componentDefine, to: JSValue.self)

            var exceptionInfo: String?
            self.runtimeContext.exceptionHandler = { context, exception in
                print("execute exception : \(exception!.toString() ?? "exception is nil")")
                exceptionInfo = exception?.toString()
                semaphore.signal()
            }
            
            let errorWidget:@convention(block) (String)->Void = { error in
                exceptionInfo = error;
                semaphore.signal()
            }
            self.runtimeContext["$error"] = unsafeBitCast(errorWidget, to: JSValue.self)
            
            
            let importJS:@convention(block) (String) -> Bool = { [weak self] relativeFilePath in
                print("import \(relativeFilePath)")
                
                
                // read file
                guard let fileContent = self?.package.readFile(relativePath: relativeFilePath).0 else {
                    return false
                }
                
                // transform
                var executeResult = true
                let _ = self?.transform(fileContent, wrapMain: false)
                    .sink(receiveCompletion: { completion in
                        print("import completion : \(completion)")
                        switch completion {
                        case .failure(let error):
                            print("import execute error : \(error)")
                            executeResult = false
                        case .finished:
                            print("import execute finished")
                        }
                    }, receiveValue: { JavaScriptContent in
                        // execute
                        print("//////////////////////////////////////////////")
                        print(JavaScriptContent)
                        print("\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\")
                        self?.runtimeContext.evaluateScript(JavaScriptContent)
                    })
                
                return executeResult
            }
            self.runtimeContext["$import"] = unsafeBitCast(importJS, to: JSValue.self)
            
            // Execute support js
            self.runtimeContext.evaluateScript(supportJS)
            
            // moment.min.js
            if let momentJS = self.readSupportScript("moment.min.js") {
                self.runtimeContext.evaluateScript(momentJS)
            }
            
            // Execute target code
            self.runtimeContext.evaluateScript(JavaScript)
                        
            // Check render
            guard let mainEntry = self.runtimeContext.objectForKeyedSubscript("$main") else {
                promise(.failure(.internalError("$main() is not defined")))
                return
            }
            if mainEntry.isUndefined {
                promise(.failure(.undefinedRender("$main() is not defined")))
                return
            }

            // Call main
            let _ = mainEntry.call(withArguments: [])
            
            
            // Make sure $render be called
            if !JavaScript.contains("$render") {
                resultElement = ScriptWidgetRuntimeElement(tagString: "text", props: nil, children: ["#UI Not Found#"])
                semaphore.signal()
            }

            DispatchQueue.global().async {
                semaphore.wait()
                // check javascript exception
                if let exceptionInfo = exceptionInfo {
                    promise(.failure(.scriptException(exceptionInfo)))
                    return
                }
                
                guard let element = resultElement else {
                    promise(.failure(.scriptError("Transform result is not Element : \(String(describing: resultElement))")))
                    return
                }
                
                // success
                promise(.success(element))
            }
        }
        .eraseToAnyPublisher()
    }
    
    
}

extension ScriptWidgetRuntime {
    
    func executeJSXSyncForDynamicIsland(_ JSX: String) -> (ScriptWidgetDynamicIslandRuntimeElement? , ScriptWidgetError?) {
        var resultError: ScriptWidgetError?
        var resultElement: ScriptWidgetDynamicIslandRuntimeElement?
        
        let sem = DispatchSemaphore(value: 0)
        var cancellables: [AnyCancellable] = []

        DispatchQueue.global().async {
            
            let cancelable = self.internalExecuteJSXForDynamicIsland(JSX)
                .sink { (completion) in
                    switch completion {
                    case .finished:
                        print("script run finished")
                        
                        sem.signal()
                        
                    case .failure(let error):
                        print("failed : \(error)")
                        resultError = error
                        
                        sem.signal()
                    }
                } receiveValue: { (element) in
                    print("-------------------------------------------")
                    print(element)
                    print("]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]")
                    resultElement = element
                }
            cancellables.append(cancelable)
        }
        
        sem.wait()
        
        return (resultElement, resultError)
    }
    
    private func internalExecuteJSXForDynamicIsland(_ JSX: String) -> AnyPublisher<ScriptWidgetDynamicIslandRuntimeElement, ScriptWidgetError> {
        return transform(JSX, wrapMain: true)
            .flatMap { JavaScript -> AnyPublisher<ScriptWidgetDynamicIslandRuntimeElement, ScriptWidgetError> in
                print("[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[")
                print(JavaScript)

                return self.internalExecuteJavaScriptForDynamicIsland(JavaScript)
            }
            .eraseToAnyPublisher()
    }
    
    /*
     load JavaScript and call render()

     const render = () => {
         return (
             <text>Hello SwiftWidget</text>
         )
     }
     */
    private func internalExecuteJavaScriptForDynamicIsland(_ JavaScript: String) -> AnyPublisher<ScriptWidgetDynamicIslandRuntimeElement, ScriptWidgetError> {
        return Future<ScriptWidgetDynamicIslandRuntimeElement, ScriptWidgetError> { promise in
            guard let supportJS = self.readSupportScript("util.js") else {
                promise(.failure(.internalError("scriptwidget not found")))
                return
            }
                        
            // Inject ScriptWidgetRuntime JavaScript Object
            self.runtimeContext["Promise"] = ScriptWidgetRuntimePromise.self
            self.runtimeContext["fetch"] = unsafeBitCast(custom_fetch, to: JSValue.self)
            self.runtimeContext["$fetch"] = unsafeBitCast(custom_fetch, to: JSValue.self)

            self.runtimeContext["$console"] = ScriptWidgetRuntimeConsole.self
            self.runtimeContext["console"] = ScriptWidgetRuntimeConsole.self
            
            self.runtimeContext["$element"] = ScriptWidgetRuntimeElement.self
            self.runtimeContext["$device"] = ScriptWidgetRuntimeDevice.self
            self.runtimeContext["$http"] = ScriptWidgetRuntimeHttp.self
            self.runtimeContext["$file"] = ScriptWidgetRuntimeFile.self

            let custom_getenv:@convention(block) (String)-> String = { [weak self] (key) in
                if let value = self?.environments[key] {
                    return value
                }
                return ""
            }
            self.runtimeContext["$getenv"] = unsafeBitCast(custom_getenv, to: JSValue.self)
            
            let semaphore = DispatchSemaphore(value: 0)
            var resultElement: ScriptWidgetDynamicIslandRuntimeElement?
            
            // ignore for dynamic island
            let renderWidget:@convention(block) (ScriptWidgetRuntimeElement)->Void = { rootElement in
                print("ignore $render for dynamic island : root element = \(rootElement)")
                semaphore.signal()
            }
            self.runtimeContext["$render"] = unsafeBitCast(renderWidget, to: JSValue.self)
            
            // ignore for dynamic island
            // -begin
            let renderDynamicIsland:@convention(block) (NSDictionary)->Void = { islandInfo in
                print("not support in normal widget rendering : islandInfo = \(islandInfo)")
                
                guard let minimal = islandInfo["minimal"] as? ScriptWidgetRuntimeElement,
                   let compactLeading = islandInfo["compactLeading"] as? ScriptWidgetRuntimeElement,
                   let compactTrailing = islandInfo["compactTrailing"] as? ScriptWidgetRuntimeElement,
                      let expandedInfo = islandInfo["expanded"] as? NSDictionary else {
                    print("some dynamic island fields not found")
                    semaphore.signal()
                    return
                }
                
                let expandedLeading = expandedInfo["leading"] as? ScriptWidgetRuntimeElement
                let expandedTrailing = expandedInfo["trailing"] as? ScriptWidgetRuntimeElement
                let expandedCenter = expandedInfo["center"] as? ScriptWidgetRuntimeElement
                let expandedBottom = expandedInfo["bottom"] as? ScriptWidgetRuntimeElement
                
                let resultExpanded = ScriptWidgetDynamicIslandRuntimeElement.ExpandedElement(leading: expandedLeading, trailing: expandedTrailing, center: expandedCenter, bottom: expandedBottom)
                
                resultElement = ScriptWidgetDynamicIslandRuntimeElement(expanded: resultExpanded, compactLeading: compactLeading, compactTrailing: compactTrailing, minimal: minimal)
                
                semaphore.signal()
            }
            self.runtimeContext["$dynamic_island"] = unsafeBitCast(renderDynamicIsland, to: JSValue.self)
            // -end
            
            let componentDefine:@convention(block) (String, JSValue) -> Void = { [weak self](name, builder) in
                print("define component : \(name) , \(type(of: builder))")
                
                if let type = self?.getTypeOfValue(builder) {
                    print("builder type = \(type)")
                }
            }
            self.runtimeContext["$component"] = unsafeBitCast(componentDefine, to: JSValue.self)

            var exceptionInfo: String?
            self.runtimeContext.exceptionHandler = { context, exception in
                print("execute exception : \(exception!.toString() ?? "exception is nil")")
                exceptionInfo = exception?.toString()
                semaphore.signal()
            }
            
            let errorWidget:@convention(block) (String)->Void = { error in
                exceptionInfo = error;
                semaphore.signal()
            }
            self.runtimeContext["$error"] = unsafeBitCast(errorWidget, to: JSValue.self)
            
            
            let importJS:@convention(block) (String) -> Bool = { [weak self] relativeFilePath in
                print("import \(relativeFilePath)")
                
                
                // read file
                guard let fileContent = self?.package.readFile(relativePath: relativeFilePath).0 else {
                    return false
                }
                
                // transform
                var executeResult = true
                let _ = self?.transform(fileContent, wrapMain: false)
                    .sink(receiveCompletion: { completion in
                        print("import completion : \(completion)")
                        switch completion {
                        case .failure(let error):
                            print("import execute error : \(error)")
                            executeResult = false
                        case .finished:
                            print("import execute finished")
                        }
                    }, receiveValue: { JavaScriptContent in
                        // execute
                        print("//////////////////////////////////////////////")
                        print(JavaScriptContent)
                        print("\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\")
                        self?.runtimeContext.evaluateScript(JavaScriptContent)
                    })
                
                return executeResult
            }
            self.runtimeContext["$import"] = unsafeBitCast(importJS, to: JSValue.self)
            
            // Execute support js
            self.runtimeContext.evaluateScript(supportJS)
            
            // moment.min.js
            if let momentJS = self.readSupportScript("moment.min.js") {
                self.runtimeContext.evaluateScript(momentJS)
            }
            
            // Execute target code
            self.runtimeContext.evaluateScript(JavaScript)
                        
            // Check render
            guard let mainEntry = self.runtimeContext.objectForKeyedSubscript("$main") else {
                promise(.failure(.internalError("$main() is not defined")))
                return
            }
            if mainEntry.isUndefined {
                promise(.failure(.undefinedRender("$main() is not defined")))
                return
            }

            // Call main
            let _ = mainEntry.call(withArguments: [])
            
            
            // Make sure $dynamic_island be called
            if !JavaScript.contains("$dynamic_island") {
                resultElement = ScriptWidgetDynamicIslandRuntimeElement(text: "$dynamic_island call not found")
                semaphore.signal()
            }

            DispatchQueue.global().async {
                semaphore.wait()
                // check javascript exception
                if let exceptionInfo = exceptionInfo {
                    promise(.failure(.scriptException(exceptionInfo)))
                    return
                }
                
                guard let element = resultElement else {
                    promise(.failure(.scriptError("Transform result is not Element : \(String(describing: resultElement))")))
                    return
                }
                
                // success
                promise(.success(element))
            }
        }
        .eraseToAnyPublisher()
    }
    
}

extension ScriptWidgetRuntime {
    
    func executeJSXSyncForFunction(_ JSX: String, _ functionName: String) -> (String? , ScriptWidgetError?) {
        var resultError: ScriptWidgetError?
        var resultElement: String?
        
        let sem = DispatchSemaphore(value: 0)
        var cancellables: [AnyCancellable] = []

        DispatchQueue.global().async {
            
            let cancelable = self.internalExecuteJSXForFunction(JSX, functionName)
                .sink { (completion) in
                    switch completion {
                    case .finished:
                        print("script run finished")
                        
                        sem.signal()
                        
                    case .failure(let error):
                        print("failed : \(error)")
                        resultError = error
                        
                        sem.signal()
                    }
                } receiveValue: { (element) in
                    print("-------------------------------------------")
                    print(element)
                    print("]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]")
                    resultElement = element
                }
            cancellables.append(cancelable)
        }
        
        sem.wait()
        
        return (resultElement, resultError)
    }
    
    private func internalExecuteJSXForFunction(_ JSX: String, _ functionName: String) -> AnyPublisher<String, ScriptWidgetError> {
        return transform(JSX, wrapMain: true, callAsynFunctionName: functionName)
            .flatMap { JavaScript -> AnyPublisher<String, ScriptWidgetError> in
                print("[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[")
                print(JavaScript)

                return self.internalExecuteJavaScriptForFunction(JavaScript)
            }
            .eraseToAnyPublisher()
    }
    
    /*
     load JavaScript and call function()

     const onButtonClick = () => {
        return "result string";
     }
     */
    private func internalExecuteJavaScriptForFunction(_ JavaScript: String) -> AnyPublisher<String, ScriptWidgetError> {
        return Future<String, ScriptWidgetError> { promise in
            guard let supportJS = self.readSupportScript("util.js") else {
                promise(.failure(.internalError("scriptwidget not found")))
                return
            }
                        
            // Inject ScriptWidgetRuntime JavaScript Object
            self.runtimeContext["Promise"] = ScriptWidgetRuntimePromise.self
            self.runtimeContext["fetch"] = unsafeBitCast(custom_fetch, to: JSValue.self)
            self.runtimeContext["$fetch"] = unsafeBitCast(custom_fetch, to: JSValue.self)

            self.runtimeContext["$console"] = ScriptWidgetRuntimeConsole.self
            self.runtimeContext["console"] = ScriptWidgetRuntimeConsole.self
            
            self.runtimeContext["$element"] = ScriptWidgetRuntimeElement.self
            self.runtimeContext["$device"] = ScriptWidgetRuntimeDevice.self
            self.runtimeContext["$http"] = ScriptWidgetRuntimeHttp.self
            self.runtimeContext["$file"] = ScriptWidgetRuntimeFile.self

            let custom_getenv:@convention(block) (String)-> String = { [weak self] (key) in
                if let value = self?.environments[key] {
                    return value
                }
                return ""
            }
            self.runtimeContext["$getenv"] = unsafeBitCast(custom_getenv, to: JSValue.self)
            
            let semaphore = DispatchSemaphore(value: 0)
            
            let renderWidget:@convention(block) (ScriptWidgetRuntimeElement)->Void = { rootElement in
                print("not support in function calling mode = \(rootElement)")
                semaphore.signal()
            }
            self.runtimeContext["$render"] = unsafeBitCast(renderWidget, to: JSValue.self)
            
            // ignore for dynamic island
            // -begin
            let renderDynamicIsland:@convention(block) (NSDictionary)->Void = { islandInfo in
                print("not support in normal widget rendering : islandInfo = \(islandInfo)")
                semaphore.signal()
            }
            self.runtimeContext["$dynamic_island"] = unsafeBitCast(renderDynamicIsland, to: JSValue.self)
            // -end
            
            
            var exceptionInfo: String?
            self.runtimeContext.exceptionHandler = { context, exception in
                print("execute exception : \(exception!.toString() ?? "exception is nil")")
                exceptionInfo = exception?.toString()
                semaphore.signal()
            }
            
            let errorWidget:@convention(block) (String)->Void = { error in
                exceptionInfo = error;
                semaphore.signal()
            }
            self.runtimeContext["$error"] = unsafeBitCast(errorWidget, to: JSValue.self)
            
            
            let importJS:@convention(block) (String) -> Bool = { [weak self] relativeFilePath in
                print("import \(relativeFilePath)")
                
                
                // read file
                guard let fileContent = self?.package.readFile(relativePath: relativeFilePath).0 else {
                    return false
                }
                
                // transform
                var executeResult = true
                let _ = self?.transform(fileContent, wrapMain: false)
                    .sink(receiveCompletion: { completion in
                        print("import completion : \(completion)")
                        switch completion {
                        case .failure(let error):
                            print("import execute error : \(error)")
                            executeResult = false
                        case .finished:
                            print("import execute finished")
                        }
                    }, receiveValue: { JavaScriptContent in
                        // execute
                        print("//////////////////////////////////////////////")
                        print(JavaScriptContent)
                        print("\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\")
                        self?.runtimeContext.evaluateScript(JavaScriptContent)
                    })
                
                return executeResult
            }
            self.runtimeContext["$import"] = unsafeBitCast(importJS, to: JSValue.self)
            
            // Execute support js
            self.runtimeContext.evaluateScript(supportJS)
            
            // moment.min.js
            if let momentJS = self.readSupportScript("moment.min.js") {
                self.runtimeContext.evaluateScript(momentJS)
            }
            
            // Execute target code
            self.runtimeContext.evaluateScript(JavaScript)
                        
            // Check render
            guard let mainEntry = self.runtimeContext.objectForKeyedSubscript("$main") else {
                promise(.failure(.internalError("$main() is not defined")))
                return
            }
            if mainEntry.isUndefined {
                promise(.failure(.undefinedRender("$main() is not defined")))
                return
            }

            // Call main
            let _ = mainEntry.call(withArguments: [])

            DispatchQueue.global().async {
                semaphore.wait()
                // check javascript exception
                if let exceptionInfo = exceptionInfo {
                    promise(.failure(.scriptException(exceptionInfo)))
                    return
                }
                
                // success
                promise(.success(""))
            }
        }
        .eraseToAnyPublisher()
    }
    
    
}
