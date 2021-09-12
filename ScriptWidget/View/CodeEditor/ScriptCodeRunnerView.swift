//
//  ScriptCodeRunnerView.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/10/30.
//

import SwiftUI
import Combine



struct ScriptConsoleOutput : Identifiable {
    let id = UUID()
    let data: String
    let smallSize: Bool
}

class ScriptCodeRunnerDataObject : ObservableObject {
    let file: ScriptWidgetFile
    var widgetSizeType: Int
    
    @Published var consoleOutputs : [ScriptConsoleOutput] = []
    @Published var rootElement : ScriptWidgetRuntimeElement
    
    
    init(file: ScriptWidgetFile, widgetSizeType: Int) {
        // force save
        NotificationCenter.default.post(name: CodeEditorViewController.needSaveFileNotification, object: nil, userInfo: nil)
        
        self.widgetSizeType = widgetSizeType
        self.file = file
        self.rootElement = ScriptWidgetRuntimeElement(tag: "text", props: nil, children: ["#Loading#"])
        
        self.layoutElements()
    }
    
    func changeWidgetSizeType(_ newWidgetSizeType : Int) {
        self.widgetSizeType = newWidgetSizeType
        
        self.layoutElements()
    }
    
    func layoutElements() {
        if !self.runScript() {
            self.rootElement = ScriptWidgetRuntimeElement(tag: "text", props: nil, children: ["#Failed#"])
        }
    }
    
    func runScript() -> Bool {
        sharedConsoleLogManager.clear()
        self.clearLogs()
        
        self.systemLog("START")
        
        guard let JSX = self.file.readFile() else {
            self.systemLog("Can not open file")
            return false
        }
        
        var returnValue = false
        
        var widgetSizeString = ""
        switch widgetSizeType {
        case 0: widgetSizeString = "small"
        case 1: widgetSizeString = "medium"
        case 2: widgetSizeString = "large"
        default: widgetSizeString = "small"
        }
        
        let runtime = ScriptWidgetRuntime(environments: [
            "widget-size": widgetSizeString
        ])
        
        let result = runtime.executeJSXSync(JSX)
        
        if let element = result.0 {
            // succeed
            self.rootElement = element
            returnValue = true
        } else {
            // error
            returnValue = false
            if let error = result.1 {
                switch error {
                case .undefinedRender(let msg):
                    self.systemLog(msg)
                case .internalError(let msg):
                    self.systemLog(msg)
                case .scriptError(let msg):
                    self.systemLog(msg)
                case .scriptException(let msg):
                    self.systemLog(msg)
                case .transformError(let msg):
                    self.systemLog(msg)
                }
            }
        }
        
        DispatchQueue.main.async {
            self.loadScriptConsoleLogs()
            self.systemLog("FINISH")
        }
        
        return returnValue
    }
    
    func loadScriptConsoleLogs() {
        let logs = sharedConsoleLogManager.logs
        for log in logs {
            self.scriptLog(log)
        }
    }
    
    func clearLogs() {
        DispatchQueue.main.async {
            self.consoleOutputs.removeAll()
        }
    }
    
    func scriptLog(_ str: String) {
        DispatchQueue.main.async {
            self.consoleOutputs.append(ScriptConsoleOutput(data: str, smallSize: false))
        }
    }
    
    func systemLog(_ str: String) {
        DispatchQueue.main.async {
            self.consoleOutputs.append(ScriptConsoleOutput(data: "$ \(str)", smallSize: true))
        }
    }
}

struct ScriptCodeRunnerView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var data: ScriptCodeRunnerDataObject
    @State var widgetSizeType = 0
    @State var isDebugMode = false
    
    @State var showToastCopied = false
    
    init(file: ScriptWidgetFile) {
        self.data = ScriptCodeRunnerDataObject(file: file, widgetSizeType: 0)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Spacer()
                
                Text("Preview")
                    .font(.body)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button (action: {
                    presentationMode.wrappedValue.dismiss()
                }, label: {
                    Image(systemName: "xmark")
                })
            }
            .padding()
            
            Section {
                HStack {
                    Text("Preview Size")
                        .font(.headline)
                    Picker(selection: $widgetSizeType, label:Text("Preview Size")) {
                        Text("Small").tag(0)
                        Text("Medium").tag(1)
                        Text("Large").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: widgetSizeType, perform: { value in
                        print("preview size changed : \(value)")
                        
                        self.data.changeWidgetSizeType(value)
                    })
                }
                
                Toggle(isOn: $isDebugMode) {
                    Text("Debug Line")
                        .font(.headline)
                }
                
            }
            .padding(.leading)
            .padding(.trailing)
            
            ZStack {
                Rectangle()
                    .fill(Color.secondary)
                ScriptWidgetElementView(element: data.rootElement, context: ScriptWidgetElementContext(debugMode: isDebugMode))
                    .frame(
                        width: WidgetSizeHelper.size(Int32(self.widgetSizeType)).width,
                        height: WidgetSizeHelper.size(Int32(self.widgetSizeType)).height
                    )
                    .background(UITraitCollection.current.userInterfaceStyle == .dark ? Color.black : Color.white)
                    .cornerRadius(10)
            }
            .frame(height: WidgetSizeHelper.size(Int32(self.widgetSizeType)).height + 5)
            
            List {
                ForEach(data.consoleOutputs) { item in
                    Text(item.data)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .font(.footnote)
                        .onTapGesture(count: 2) {
                            UIPasteboard.general.string = item.data
                            self.showToastCopied.toggle()
                        }
                }
            }
        }
        .simpleToast(isShowing: $showToastCopied, options: SimpleToastOptions(hideAfter: 1)) {
            HStack {
                Text("console text copied")
            }
            .padding()
            .background(Color.blue.opacity(0.8))
            .foregroundColor(Color.white)
            .cornerRadius(5)
        }
    }
    
    
}

struct ScriptCodeRunnerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ScriptCodeRunnerView(file: globalScriptWidgetFile)
                .preferredColorScheme(.light)
            ScriptCodeRunnerView(file: globalScriptWidgetFile)
                .preferredColorScheme(.dark)
        }
    }
}
