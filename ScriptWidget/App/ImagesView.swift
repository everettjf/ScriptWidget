//
//  ImageListView.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/11/3.
//

import SwiftUI
import SDWebImageSwiftUI

class ImageDataObject: ObservableObject {
    @Published var smallImages = [ImageModel]()
    @Published var mediumImages = [ImageModel]()
    @Published var largeImages = [ImageModel]()
    
    public static let imageDeleteNotification = Notification.Name("ImageDataObjectImageDeleteNotification")
    public static let imageRenameNotification = Notification.Name("ImageDataObjectImageRenameNotification")

    init() {
        reload()
        
        NotificationCenter.default.addObserver(forName: PhotoPickerViewController.newSaveNotification, object: nil, queue: OperationQueue.main) { (noti) in
            self.reload()
        }
        
        NotificationCenter.default.addObserver(forName: ImageDataObject.imageDeleteNotification, object: nil, queue: OperationQueue.main) { (noti) in
            self.reload()
        }
        
        NotificationCenter.default.addObserver(forName: ImageDataObject.imageRenameNotification, object: nil, queue: OperationQueue.main) { (noti) in
            self.reload()
        }
    }
    
    
    func reload() {
        DispatchQueue.global().async { [self] in
            
            let images = sharedImageManager.listImages()
            
            DispatchQueue.main.async {
                self.smallImages = images.small
                self.mediumImages = images.medium
                self.largeImages = images.large
            }
        }
    }
}

struct ImageItemView: View {
    let image: ImageModel
    
    var body: some View {
        VStack {
            WebImage(url: image.filePath)
                .resizable()
                .placeholder {
                    Rectangle().foregroundColor(.gray)
                }
                .frame(
                    width: ImageHelper.getItemWidth(widgetSizeType: image.widgetSizeType) / 2,
                    height: ImageHelper.getItemHeight(widgetSizeType: image.widgetSizeType) / 2)
                .cornerRadius(10)
            
            
            Text("\(image.imageId)")
                .font(.subheadline)
        }
    }
}


struct ImagesView: View {
    @ObservedObject var dataObject = ImageDataObject()
    
    @State private var isAddingImage: Bool = false
    @State private var previewingImage: ImageModel?
    
    
    
    let smallColumns = [
        GridItem(.fixed(ImageHelper.getItemWidth(widgetSizeType: 0) / 2), spacing:5),
        GridItem(.fixed(ImageHelper.getItemWidth(widgetSizeType: 0) / 2), spacing:5),
        GridItem(.fixed(ImageHelper.getItemWidth(widgetSizeType: 0) / 2), spacing:5),
        GridItem(.fixed(ImageHelper.getItemWidth(widgetSizeType: 0) / 2), spacing:5)
    ]
    
    let mediumColumns = [
        GridItem(.fixed(ImageHelper.getItemWidth(widgetSizeType: 1) / 2), spacing:5),
        GridItem(.fixed(ImageHelper.getItemWidth(widgetSizeType: 1) / 2), spacing:5)
    ]
    
    let largeColumns = [
        GridItem(.fixed(ImageHelper.getItemWidth(widgetSizeType: 2) / 2), spacing:5),
        GridItem(.fixed(ImageHelper.getItemWidth(widgetSizeType: 2) / 2), spacing:5)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid (columns: smallColumns, alignment: .center, spacing: 5, pinnedViews: [.sectionHeaders, .sectionFooters]) {
                
                
                Section(header: Text("Small Widget Images (\(dataObject.smallImages.count))").font(.subheadline).fontWeight(.bold)) {
                    ForEach(dataObject.smallImages) { item in
                        Button(action: {
                            self.previewingImage = item
                        }) {
                            ImageItemView(image: item)
                        }
                    }
                }
            }
            
            LazyVGrid (columns: mediumColumns, alignment: .center, spacing: 5, pinnedViews: [.sectionHeaders, .sectionFooters]) {
                
                Section(header: Text("Medium Widget Images (\(dataObject.mediumImages.count))").font(.subheadline).fontWeight(.bold)) {
                    
                    ForEach(dataObject.mediumImages) { item in
                        Button(action: {
                            self.previewingImage = item
                        }) {
                            ImageItemView(image: item)
                        }
                    }
                }
            }
            
            LazyVGrid (columns: largeColumns, alignment: .center, spacing: 5, pinnedViews: [.sectionHeaders, .sectionFooters]) {
                
                
                Section(header: Text("Large Widget Images (\(dataObject.largeImages.count))").font(.subheadline).fontWeight(.bold)) {
                    
                    ForEach(dataObject.largeImages) { item in
                        Button(action: {
                            self.previewingImage = item
                        }) {
                            ImageItemView(image: item)
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: self.$previewingImage) { item in
            ImagePreviewView(image: item)
        }
        .navigationBarTitle("Images", displayMode: .inline)
        .navigationBarItems(
            trailing:Button(action: {
                isAddingImage = true
            }) {
                Image(systemName: "plus.square")
                    .padding(.leading, 30)
                    .padding(.top, 5)
                    .padding(.bottom, 5)
                
            }
            .sheet(isPresented: $isAddingImage) {
                PhotoPickerView()
            }
        )
    }
}

struct ImagesView_Previews: PreviewProvider {
    static var previews: some View {
        ImagesView()
    }
}

