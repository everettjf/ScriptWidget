//
//  InputAlertHelper.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/17.
//

import SwiftUI
import UIKit



extension UIAlertController {
    convenience init(alert: TextAlert) {
        self.init(title: alert.title, message: nil, preferredStyle: .alert)
        if alert.showTextField {
            addTextField { field in
                field.placeholder = alert.placeholder
                field.text = alert.textDefaultValue
            }
        }
        
        addAction(UIAlertAction(title: alert.cancel, style: .cancel) { _ in
            alert.actionCancel()
        })
        
        let textField = self.textFields?.first
        addAction(UIAlertAction(title: alert.accept, style: .default) { _ in
            alert.actionAccept(textField?.text)
        })
    }
}



struct AlertWrapper<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let alert: TextAlert
    let content: Content
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<AlertWrapper>) -> UIHostingController<Content> {
        UIHostingController(rootView: content)
    }
    
    final class Coordinator {
        var alertController: UIAlertController?
        init(_ controller: UIAlertController? = nil) {
            self.alertController = controller
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    
    func updateUIViewController(_ uiViewController: UIHostingController<Content>, context: UIViewControllerRepresentableContext<AlertWrapper>) {
        uiViewController.rootView = content
        if isPresented && uiViewController.presentedViewController == nil {
            var alert = self.alert
            alert.actionAccept = {
                self.isPresented = false
                self.alert.actionAccept($0)
            }
            alert.actionCancel = {
                self.isPresented = false
            }
            context.coordinator.alertController = UIAlertController(alert: alert)
            uiViewController.present(context.coordinator.alertController!, animated: true)
        }
        if !isPresented && uiViewController.presentedViewController == context.coordinator.alertController {
            uiViewController.dismiss(animated: true)
        }
    }
}

public struct TextAlert {
    public var title: String
    public var showTextField: Bool = true
    public var placeholder: String = ""
    public var textDefaultValue: String = ""
    public var accept: String = "Confirm"
    public var cancel: String = "Cancel"
    public var actionAccept: (String?) -> Void
    public var actionCancel: () -> Void
}

extension View {
    public func inputAlert(isPresented: Binding<Bool>, _ alert: TextAlert) -> some View {
        AlertWrapper(isPresented: isPresented, alert: alert, content: self)
    }
}

struct InputAlertHelper: View {
    
    @State var showsAlert = false
    var body: some View {
        VStack {
            Button("alert") {
                self.showsAlert = true
            }
        }
        .inputAlert(isPresented: $showsAlert, TextAlert(title: "Title", actionAccept: {
            print("Callback \($0 ?? "<cancel>")")
        }, actionCancel: {}))
    }
}

struct InputAlertHelper_Previews: PreviewProvider {
    static var previews: some View {
        InputAlertHelper()
    }
}
