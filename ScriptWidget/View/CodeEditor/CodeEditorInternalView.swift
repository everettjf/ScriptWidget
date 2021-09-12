//
//  CodeEditorView.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/10/24.
//

import SwiftUI


struct CodeEditorInternalView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode

    let file: ScriptWidgetFile
    
    typealias UIViewControllerType = CodeEditorViewController
    
    init(file: ScriptWidgetFile) {
        self.file = file
    }
    
    func makeUIViewController(context: Context) -> CodeEditorViewController {
        let storyboard = UIStoryboard(name: "CodeEditor", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "CodeEditorViewController") as! CodeEditorViewController
        vc.file = file
        return vc
    }
    
    func updateUIViewController(_ uiViewController: CodeEditorViewController, context: Context) {
        
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: CodeEditorInternalView
        
        init(_ parent: CodeEditorInternalView) {
            self.parent = parent
        }
    }
}

struct CodeEditorView_Previews: PreviewProvider {
    static var previews: some View {

        CodeEditorInternalView(file: globalScriptModel.file)
    }
}
