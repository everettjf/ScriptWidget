//
//  PhotoPickerView.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/11/5.
//

import SwiftUI
import UIKit


struct PhotoPickerView: UIViewControllerRepresentable {
    
    // global / local
    let scriptModel: ScriptModel?
    
    @Environment(\.presentationMode) var presentationMode

    typealias UIViewControllerType = UIViewController
    
    func makeUIViewController(context: Context) -> UIViewController {
        let bundle = Bundle.main

        // Avoid a hard crash if the storyboard is accidentally missing from a build.
        guard bundle.path(forResource: "PhotoPicker", ofType: "storyboardc") != nil else {
            let vc = UIViewController()
            vc.view.backgroundColor = .systemBackground

            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.text = "Photo picker is unavailable in this build."
            label.textAlignment = .center
            label.numberOfLines = 0
            label.textColor = .secondaryLabel

            vc.view.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 24),
                label.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -24),
                label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
            ])
            return vc
        }

        let storyboard = UIStoryboard(name: "PhotoPicker", bundle: bundle)
        let viewController = storyboard.instantiateViewController(identifier: "PhotoPickerViewController")
        guard let vc = viewController as? PhotoPickerViewController else {
            return UIViewController()
        }

        vc.popAction = {
            self.presentationMode.wrappedValue.dismiss()
        }
        vc.scriptModel = self.scriptModel
        return vc
    }
    
    func updateUIViewController(_ vc: UIViewController, context: Context) {
        guard let picker = vc as? PhotoPickerViewController else { return }
        picker.scriptModel = self.scriptModel
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: PhotoPickerView
        
        init(_ parent: PhotoPickerView) {
            self.parent = parent
        }
    }
}
//struct PhotoPickerView_Previews: PreviewProvider {
//    static var previews: some View {
//        PhotoPickerView()
//    }
//}
