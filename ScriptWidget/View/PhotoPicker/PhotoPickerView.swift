//
//  PhotoPickerView.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/11/5.
//

import SwiftUI


struct PhotoPickerView: UIViewControllerRepresentable {
    
    @Environment(\.presentationMode) var presentationMode

    typealias UIViewControllerType = PhotoPickerViewController
    
    func makeUIViewController(context: Context) -> PhotoPickerViewController {
        let storyboard = UIStoryboard(name: "PhotoPicker", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "PhotoPickerViewController") as! PhotoPickerViewController
        vc.popAction = {
            self.presentationMode.wrappedValue.dismiss()
        }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: PhotoPickerViewController, context: Context) {

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
struct PhotoPickerView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoPickerView()
    }
}
