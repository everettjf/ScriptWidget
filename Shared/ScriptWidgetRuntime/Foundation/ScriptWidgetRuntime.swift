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


class ScriptWidgetRuntime {
    
    private let runtimeContext = JSContext()!
    
    private let environments : [String:String]
    
    init(environments: [String:String]) {
        self.environments = environments
    }
    
    func executeJSXSync(_ JSX: String) -> (ScriptWidgetRuntimeElement? , ScriptWidgetError?) {
        var resultError: ScriptWidgetError?
        var resultElement: ScriptWidgetRuntimeElement?
        
        let sem = DispatchSemaphore(value: 0)
        var cancellables: [AnyCancellable] = []

        DispatchQueue.global().async {
            
            let cancelable = self.executeJSX(JSX)
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
    
    private func executeJSX(_ JSX: String) -> AnyPublisher<ScriptWidgetRuntimeElement, ScriptWidgetError> {
        return transform(JSX)
            .flatMap { JavaScript -> AnyPublisher<ScriptWidgetRuntimeElement, ScriptWidgetError> in
                print("[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[")
                print(JavaScript)

                return self.executeJavaScript(JavaScript)
            }
            .eraseToAnyPublisher()
    }
    
    private func readSupportScript(_ fileName: String) -> String? {
        return ScriptWidgetBundle.readFile(bundle: "support", fileName: fileName)
    }
    
    private func transform(_ paramJSX: String) -> AnyPublisher<String, ScriptWidgetError> {
        // async/await support
        let JSX =
            "async function $main() { try {"
            + paramJSX
            + "} catch(e){ console.error(e); $error(`${e}`) } }"
        
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
                            var output = Babel.transform(input, { presets: ['es2015','scriptwidget'] }).code
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
    
    /*
     load JavaScript and call render()

     const render = () => {
         return (
             <text>Hello SwiftWidget</text>
         )
     }
     */
    private func executeJavaScript(_ JavaScript: String) -> AnyPublisher<ScriptWidgetRuntimeElement, ScriptWidgetError> {
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

            let environments = self.environments
            let custom_getenv:@convention(block) (String)-> String = { (key) in
                if let value = environments[key] {
                    return value
                }
                return ""
            }
            self.runtimeContext["$getenv"] = unsafeBitCast(custom_getenv, to: JSValue.self)
            
            let semaphore = DispatchSemaphore(value: 0)
            var resultElement: ScriptWidgetRuntimeElement?
            
            let renderWidget:@convention(block) (ScriptWidgetRuntimeElement)->Void = { rootElement in
                print(rootElement)
                resultElement = rootElement
                semaphore.signal()
            }
            self.runtimeContext["$render"] = unsafeBitCast(renderWidget, to: JSValue.self)
            
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
            
            // Execute support js
            self.runtimeContext.evaluateScript(supportJS)
            
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
                resultElement = ScriptWidgetRuntimeElement(tag: "text", props: nil, children: ["#UI Not Found#"])
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
