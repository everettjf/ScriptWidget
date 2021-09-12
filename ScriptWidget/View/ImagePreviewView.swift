//
//  ImagePreviewView.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/16.
//

import SwiftUI
import SDWebImageSwiftUI
import SDWebImage


struct ImagePreviewImageView: View {
    let image: ImageModel
    
    var body: some View {
        WebImage(url: image.filePath)
            .resizable()
            .placeholder {
                Rectangle().foregroundColor(.gray)
            }
            .frame(
                width: ImageHelper.getItemWidth(widgetSizeType: image.widgetSizeType),
                height: ImageHelper.getItemHeight(widgetSizeType: image.widgetSizeType))
            .cornerRadius(10)
    }
}

struct ImagePreviewView: View {
    @Environment(\.presentationMode) var presentationMode

    let image: ImageModel
    @State private var isShowingDeleteAlert = false
    @State private var isShowingRenameAlert = false
    
    init(image: ImageModel) {
        self.image = image
    }
    
    var body: some View {
        VStack(alignment:.center) {
            
            Spacer()
            
            ImagePreviewImageView(image: image)
                .cornerRadius(10)
                .padding()
            
            Button(action: {
                // alert rename
                self.isShowingRenameAlert.toggle()
            }) {
                Text(image.imageId)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .padding()
                
            }

            Spacer()
            
            Button(action: {
                // delete
                print("delete")
                self.isShowingDeleteAlert = true
            }) {
                Text("Delete")
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            presentationMode.wrappedValue.dismiss()
        }
        
        .inputAlert(isPresented: $isShowingRenameAlert, TextAlert(title: "Rename \"\(self.image.imageId)\" ?", textDefaultValue: self.image.imageId, actionAccept: { (inputText) in
            guard let newName = inputText else { return }
            if newName.isEmpty { return }
        
            print("new name = \(newName)")
            
            let result = sharedImageManager.rename(srcImageId: self.image.imageId, destImageId: newName)
            
            if result.0 {
                
                SDImageCache.shared.clearMemory()
                SDImageCache.shared.clearDisk(onCompletion: nil)

                
                NotificationCenter.default.post(name: ImageDataObject.imageRenameNotification, object: nil)

                // confirm
                self.presentationMode.wrappedValue.dismiss()
            } else {
                let error = result.1
                
                print("rename error : \(error)")
            }
        }, actionCancel: {}))
        .inputAlert(isPresented: $isShowingDeleteAlert, TextAlert(title: "Delete \"\(self.image.imageId)\" ?", showTextField: false, actionAccept: { (inputText) in
            
            // real delete
            if sharedImageManager.delete(imageId: image.imageId) {
                
                SDImageCache.shared.clearMemory()
                SDImageCache.shared.clearDisk(onCompletion: nil)
                
                NotificationCenter.default.post(name: ImageDataObject.imageDeleteNotification, object: nil)

                
                // confirm
                self.presentationMode.wrappedValue.dismiss()
                

            }
        }, actionCancel: {}))
    }
}

struct ImagePreviewView_Previews: PreviewProvider {
    static var previews: some View {
        ImagePreviewView(image: ImageModel(imageId: "image0", widgetSizeType: 0, filePath: URL(fileURLWithPath: "")))
            .preferredColorScheme(.light)
        
        
        ImagePreviewView(image: ImageModel(imageId: "image0", widgetSizeType: 1, filePath: URL(fileURLWithPath: "")))
            .preferredColorScheme(.light)
        
        
        ImagePreviewView(image: ImageModel(imageId: "image0", widgetSizeType: 2, filePath: URL(fileURLWithPath: "")))
            .preferredColorScheme(.light)
    }
}
