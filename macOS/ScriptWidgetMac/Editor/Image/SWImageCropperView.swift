//
//  SWImageCropInternalView.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/2/3.
//
//  Copy and modified from : https://github.com/ZhongUncle/SwiftUI_ImageCropper/tree/main/ImageCropper/ImageCropper


import SwiftUI


func SWCropImageInternal(_ inputImage: NSImage, toRect cropRect: CGRect, viewWidth: CGFloat, viewHeight: CGFloat) -> NSImage?
{
    let imageViewScale = max(inputImage.size.width / viewWidth,
                             inputImage.size.height / viewHeight)
    // Scale cropRect to handle images larger than shown-on-screen size
    let cropZone = CGRect(x:cropRect.origin.x * imageViewScale,
                          y:cropRect.origin.y * imageViewScale,
                          width:cropRect.size.width * imageViewScale,
                          height:cropRect.size.height * imageViewScale)
    // Perform cropping in Core Graphics
    guard let cgImage = inputImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return nil
    }
    
    guard let cutImageRef: CGImage = cgImage.cropping(to:cropZone) else {
        return nil
    }
    // Return image to NSImage
    let croppedImage: NSImage = NSImage(cgImage: cutImageRef, size: cropRect.size)
    return croppedImage
}


struct SWImageCropRatio: Identifiable {
    public let id = UUID()
    public let width: CGFloat
    public let height: CGFloat
    public let title: String
    public let image: String
    
    public func getRatio() -> CGFloat {
        return width / height
    }
    public func getRatioRevert() -> CGFloat {
        return height / width
    }
}

struct SWImageCropperView: View {
    
    public var inputImage: NSImage
    @Binding public var croppedImage: NSImage?
    public let cropRatios : [SWImageCropRatio]
    
    // Settings
    @State private var cropMode = 0 // 0 ： custom ratio ， 1 ： predefined ratio
    @State private var cropRatioIndex = -1 // index for cropRatios
    
    @State private var cropWidth: CGFloat = 169
    @State private var cropHeight: CGFloat = 169
    
    @State private var cropBorderColor = Color.pink
    @State private var imageDisplayWidth: CGFloat = 0
    @State private var imageDisplayHeight: CGFloat = 0
    @State private var cropWidthAdd: CGFloat = 0
    @State private var cropHeightAdd: CGFloat = 0
    
    @State private var currentPositionZS: CGSize = .zero
    @State private var newPositionZS: CGSize = .zero
    
    @State private var currentPositionZ: CGSize = .zero
    @State private var newPositionZ: CGSize = .zero
    
    @State private var currentPositionZX: CGSize = .zero
    @State private var newPositionZX: CGSize = .zero
    
    @State private var currentPositionX: CGSize = .zero
    @State private var newPositionX: CGSize = .zero
    
    @State private var currentPositionYX: CGSize = .zero
    @State private var newPositionYX: CGSize = .zero
    
    @State private var currentPositionY: CGSize = .zero
    @State private var newPositionY: CGSize = .zero
    
    @State private var currentPositionYS: CGSize = .zero
    @State private var newPositionYS: CGSize = .zero
    
    @State private var currentPositionS: CGSize = .zero
    @State private var newPositionS: CGSize = .zero
    
    @State private var currentPositionCrop: CGSize = .zero
    @State private var newPositionCrop: CGSize = .zero
    
    
    var body: some View {
        ZStack {
            VStack {
                ZStack {
                    ZStack {
                        Image(nsImage: inputImage)
                            .resizable()
                            .scaledToFit()
                            .overlay(GeometryReader{geo -> AnyView in
                                DispatchQueue.main.async{
                                    self.imageDisplayWidth = geo.size.width
                                    self.imageDisplayHeight = geo.size.height
                                }
                                return AnyView(EmptyView())
                            })
                        
                        
                        //裁剪框
                        ZStack {
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: cropWidth+cropWidthAdd, height: cropHeight+cropHeightAdd)
                                .offset(x: currentPositionCrop.width, y: currentPositionCrop.height)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            //这里的newPosition表示的是当前偏移量，因为我们是通过偏移量来控制表示位置的。直接操作currentPosition会导致递归相加，这不是我们想要的。
                                            //让currentPosition 等于 新增偏移量 和 newPosition 相加，这样可以避免递归
                                            //max和min用于防止出界
                                            currentPositionCrop.width = min(max(value.translation.width + newPositionCrop.width, -imageDisplayWidth/2+cropWidth/2), imageDisplayWidth/2-cropWidth/2)
                                            currentPositionCrop.height = min(max(value.translation.height + newPositionCrop.height, -imageDisplayHeight/2+cropHeight/2), imageDisplayHeight/2-cropHeight/2)
                                            //各个角的坐标其实和Crop的一样，只是zx的减去了一半crop的偏移量作为额外的偏移量
                                            currentPositionZS = currentPositionCrop
                                            currentPositionZX = currentPositionCrop
                                            currentPositionYX = currentPositionCrop
                                            currentPositionYS = currentPositionCrop
                                            
                                            currentPositionS = currentPositionCrop
                                            currentPositionZ = currentPositionCrop
                                            currentPositionX = currentPositionCrop
                                            currentPositionY = currentPositionCrop
                                        }
                                        .onEnded { value in
                                            //移动结束后，让当前坐标的值等于之前的值加上的坐标
                                            currentPositionCrop.width = min(max(value.translation.width + newPositionCrop.width, -imageDisplayWidth/2+cropWidth/2), imageDisplayWidth/2-cropWidth/2)
                                            currentPositionCrop.height = min(max(value.translation.height + newPositionCrop.height, -imageDisplayHeight/2+cropHeight/2), imageDisplayHeight/2-cropHeight/2)
                                            //让new等于现在的坐标
                                            self.newPositionCrop = self.currentPositionCrop
                                            
                                            operateOnEnd()
                                        })
                            
                            //Sides
                            //Top
                            Rectangle()
                                .frame(width: cropWidth + cropWidthAdd, height: 1)
                                .offset(x: currentPositionS.width, y: currentPositionS.height - cropHeight/2)
                                .foregroundColor(cropBorderColor)
                                .padding(.vertical)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            var modeRatio:CGFloat = 1
                                            if cropMode == 0{
                                                //现在的高度大于40并且不超过上边界
                                                if cropHeight-value.translation.height > 40 && value.translation.height + newPositionCrop.height >= -imageDisplayHeight/2+cropHeight/2{
                                                    //自由模式
                                                    currentPositionS.height = value.translation.height + newPositionS.height
                                                    //相邻的角
                                                    currentPositionZS.height = value.translation.height + newPositionZS.height
                                                    currentPositionYS.height = value.translation.height + newPositionYS.height
                                                    //相邻的边
                                                    currentPositionY.height = value.translation.height/2 + newPositionS.height
                                                    currentPositionZ.height = value.translation.height/2 + newPositionZ.height
                                                    
                                                    currentPositionCrop.height = value.translation.height/2 + newPositionCrop.height
                                                    cropHeightAdd = -value.translation.height
                                                }
                                            }else{
                                                if cropMode == 1 {
                                                    if cropRatioIndex >= 0 && cropRatioIndex < cropRatios.count {
                                                        modeRatio = cropRatios[cropRatioIndex].getRatio()
                                                    }
                                                }
                                                
                                                //现在的高度和宽度都大于40
                                                if (cropHeight-value.translation.height > 40 || cropWidth-value.translation.height*modeRatio > 40) &&
                                                    //防止上边超过
                                                    value.translation.height + newPositionS.height >= -imageDisplayHeight/2+cropHeight/2 &&
                                                    //防止下边超过
                                                    value.translation.height + newPositionS.height <= imageDisplayHeight/2-cropHeight/2 &&
                                                    //防止右边超过
                                                    currentPositionCrop.width+(cropWidth-value.translation.height*modeRatio)/2 <= imageDisplayWidth/2 &&
                                                    //防止左边超过
                                                    currentPositionCrop.width-(cropWidth-value.translation.height*modeRatio)/2 >= -imageDisplayWidth/2 {
                                                    currentPositionS.height = value.translation.height + newPositionS.height
                                                    //相邻的角
                                                    currentPositionZS.width = value.translation.height*modeRatio/2 + newPositionZS.width
                                                    currentPositionZS.height = value.translation.height + newPositionZS.height
                                                    currentPositionYS.width = -value.translation.height*modeRatio/2 + newPositionYS.width
                                                    currentPositionYS.height = value.translation.height + newPositionYS.height
                                                    //不相邻的角
                                                    currentPositionZX.width = value.translation.height*modeRatio/2 + newPositionZX.width
                                                    currentPositionYX.width = -value.translation.height*modeRatio/2 + newPositionYX.width
                                                    //相邻的边
                                                    currentPositionY.width = -value.translation.height*modeRatio/2 + newPositionY.width
                                                    currentPositionY.height = value.translation.height/2 + newPositionY.height
                                                    currentPositionZ.width = value.translation.height*modeRatio/2 + newPositionZ.width
                                                    currentPositionZ.height = value.translation.height/2 + newPositionZ.height
                                                    //裁剪器部分
                                                    currentPositionCrop.height = value.translation.height/2 + newPositionCrop.height
                                                    cropWidthAdd = -value.translation.height*modeRatio
                                                    cropHeightAdd = -value.translation.height
                                                }
                                            }
                                        }
                                        .onEnded { value in
                                            operateOnEnd()
                                        }
                                )
                            
                            //Buttom
                            Rectangle()
                                .frame(width: cropWidth + cropWidthAdd, height: 1)
                                .foregroundColor(cropBorderColor)
                                .offset(x: currentPositionX.width, y: currentPositionX.height+cropHeight/2)
                                .padding(.vertical)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            var modeRatio:CGFloat = 1
                                            if cropMode == 0{
                                                //现在的高度大于40并且不超过下边界
                                                if cropHeight+value.translation.height > 40 && value.translation.height + newPositionCrop.height <= imageDisplayHeight/2-cropHeight/2{
                                                    //自由模式
                                                    currentPositionX.height = value.translation.height + newPositionX.height
                                                    //相邻的角
                                                    currentPositionZX.height = value.translation.height + newPositionZX.height
                                                    currentPositionYX.height = value.translation.height + newPositionYX.height
                                                    //相邻的边
                                                    currentPositionY.height = value.translation.height/2 + newPositionY.height
                                                    currentPositionZ.height = value.translation.height/2 + newPositionZ.height
                                                    //裁剪器部分
                                                    currentPositionCrop.height = value.translation.height/2 + newPositionCrop.height
                                                    cropHeightAdd = value.translation.height
                                                }
                                            }else{
                                                if cropMode == 1 {
                                                    if cropRatioIndex >= 0 && cropRatioIndex < cropRatios.count {
                                                        modeRatio = cropRatios[cropRatioIndex].getRatio()
                                                    }
                                                }
                                                if (cropHeight+value.translation.height > 40 || cropWidth+value.translation.height*modeRatio > 40) &&
                                                    //防止上边超过
                                                    value.translation.height + newPositionX.height >= -imageDisplayHeight/2+cropHeight/2 &&
                                                    //防止下边超过
                                                    value.translation.height + newPositionX.height <= imageDisplayHeight/2-cropHeight/2 &&
                                                    //防止右边超过
                                                    currentPositionCrop.width+(cropWidth+value.translation.height*modeRatio)/2 <= imageDisplayWidth/2 &&
                                                    //防止左边超过
                                                    currentPositionCrop.width-(cropWidth+value.translation.height*modeRatio)/2 >= -imageDisplayWidth/2 {
                                                    
                                                    //自由模式
                                                    currentPositionX.height = value.translation.height + newPositionX.height
                                                    //相邻的角
                                                    currentPositionZX.width = -value.translation.height*modeRatio/2 + newPositionZX.width
                                                    currentPositionZX.height = value.translation.height + newPositionZX.height
                                                    currentPositionYX.width = value.translation.height*modeRatio/2 + newPositionYX.width
                                                    currentPositionYX.height = value.translation.height + newPositionYX.height
                                                    //不相邻的角
                                                    currentPositionZS.width = -value.translation.height*modeRatio/2 + newPositionZS.width
                                                    currentPositionYS.width = value.translation.height*modeRatio/2 + newPositionYS.width
                                                    //相邻的边
                                                    currentPositionY.width = value.translation.height*modeRatio/2 + newPositionY.width
                                                    currentPositionY.height = value.translation.height/2 + newPositionY.height
                                                    currentPositionZ.width = -value.translation.height*modeRatio/2 + newPositionZ.width
                                                    currentPositionZ.height = value.translation.height/2 + newPositionZ.height
                                                    //裁剪器部分
                                                    currentPositionCrop.height = value.translation.height/2 + newPositionCrop.height
                                                    cropWidthAdd = value.translation.height*modeRatio
                                                    cropHeightAdd = value.translation.height
                                                }
                                            }
                                        }
                                        .onEnded { value in
                                            operateOnEnd()
                                        }
                                )
                            
                            //Leading
                            Rectangle()
                                .frame(width: 1, height: cropHeight + cropHeightAdd)
                                .foregroundColor(cropBorderColor)
                                .offset(x: currentPositionZ.width-cropWidth/2, y: currentPositionZ.height)
                                .padding(.horizontal)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            var modeRatio:CGFloat = 1.00
                                            if cropMode == 0{
                                                //现在的宽度大于40并且不超过左边界
                                                if cropWidth-value.translation.width > 40 && value.translation.width + newPositionCrop.width >= -imageDisplayWidth/2+cropWidth/2{
                                                    //自由模式
                                                    currentPositionZ.width = value.translation.width + newPositionZ.width
                                                    //相邻的角
                                                    currentPositionZS.width = value.translation.width + newPositionZS.width
                                                    currentPositionZS.width = value.translation.width + newPositionZS.width
                                                    currentPositionZX.width = value.translation.width + newPositionZX.width
                                                    currentPositionZX.width = value.translation.width + newPositionZX.width
                                                    //相邻的边
                                                    currentPositionS.width = value.translation.width/2 + newPositionS.width
                                                    currentPositionX.width = value.translation.width/2 + newPositionX.width
                                                    //裁剪器部分
                                                    currentPositionCrop.width = value.translation.width/2 + newPositionCrop.width
                                                    cropWidthAdd = -value.translation.width
                                                }
                                                
                                            }else{
                                                if cropMode == 1 {
                                                    if cropRatioIndex >= 0 && cropRatioIndex < cropRatios.count {
                                                        modeRatio = cropRatios[cropRatioIndex].getRatio()
                                                    }
                                                }
                                                if (cropHeight-value.translation.width/modeRatio > 40 || cropWidth-value.translation.width > 40) &&
                                                    //防止上边超过
                                                    value.translation.width/modeRatio/2 + newPositionZ.height >= -imageDisplayHeight/2+cropHeight/2 &&
                                                    //防止下边超过————这里要注意有负号
                                                    -value.translation.width/modeRatio/2 + newPositionZ.height <= imageDisplayHeight/2-cropHeight/2 &&
                                                    //防止右边超过
                                                    currentPositionCrop.width+(cropWidth-value.translation.width)/2 <= imageDisplayWidth/2 &&
                                                    //防止左边超过
                                                    currentPositionCrop.width-(cropWidth-value.translation.width)/2 >= -imageDisplayWidth/2 {
                                                    currentPositionZ.width = value.translation.width + newPositionZ.width
                                                    //相邻的角
                                                    currentPositionZS.width = value.translation.width + newPositionZS.width
                                                    currentPositionZS.height = value.translation.width/modeRatio/2 + newPositionZS.height
                                                    currentPositionZX.width = value.translation.width + newPositionZX.width
                                                    currentPositionZX.height = -value.translation.width/modeRatio/2 + newPositionZX.height
                                                    //不相邻的角
                                                    currentPositionYS.height = value.translation.width/modeRatio/2 + newPositionYS.height
                                                    currentPositionYX.height = -value.translation.width/modeRatio/2 + newPositionYX.height
                                                    //相邻的边
                                                    currentPositionS.width = value.translation.width/2 + newPositionS.width
                                                    currentPositionS.height = value.translation.width/modeRatio/2 + newPositionS.height
                                                    currentPositionX.width = value.translation.width/2 + newPositionX.width
                                                    currentPositionX.height = -value.translation.width/modeRatio/2 + newPositionX.height
                                                    //裁剪器部分
                                                    currentPositionCrop.width = value.translation.width/2 + newPositionCrop.width
                                                    cropWidthAdd = -value.translation.width
                                                    cropHeightAdd = -value.translation.width/modeRatio
                                                }
                                            }
                                        }
                                        .onEnded { value in
                                            operateOnEnd()
                                        }
                                )
                            
                            
                            
                            //Trailing
                            Rectangle()
                                .frame(width: 1, height: cropHeight + cropHeightAdd)
                                .foregroundColor(cropBorderColor)
                                .offset(x: currentPositionY.width + cropWidth/2, y: currentPositionY.height)
                                .padding(.horizontal)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            var modeRatio:CGFloat = 1.00
                                            if cropMode == 0{
                                                if cropWidth+value.translation.width > 40 && value.translation.width + newPositionCrop.width <= imageDisplayWidth/2-cropWidth/2{
                                                    //自由模式
                                                    currentPositionY.width = value.translation.width + newPositionY.width
                                                    //相邻的角
                                                    currentPositionYS.width = value.translation.width + newPositionYS.width
                                                    currentPositionYS.width = value.translation.width + newPositionYS.width
                                                    currentPositionYX.width = value.translation.width + newPositionYX.width
                                                    currentPositionYX.width = value.translation.width + newPositionYX.width
                                                    //相邻的边
                                                    currentPositionS.width = value.translation.width/2 + newPositionS.width
                                                    currentPositionX.width = value.translation.width/2 + newPositionX.width
                                                    //裁剪器部分
                                                    currentPositionCrop.width = value.translation.width/2 + newPositionCrop.width
                                                    cropWidthAdd = value.translation.width
                                                }
                                            }else{
                                                if cropMode == 1 {
                                                    if cropRatioIndex >= 0 && cropRatioIndex < cropRatios.count {
                                                        modeRatio = cropRatios[cropRatioIndex].getRatio()
                                                    }
                                                }
                                                if (cropHeight+value.translation.width/modeRatio > 40 || cropWidth+value.translation.width > 40) &&
                                                    //防止上边超过————这里要注意有负号
                                                    -value.translation.width/modeRatio/2 + newPositionY.height >= -imageDisplayHeight/2+cropHeight/2 &&
                                                    //防止下边超过
                                                    value.translation.width/modeRatio/2 + newPositionY.height <= imageDisplayHeight/2-cropHeight/2 &&
                                                    //防止右边超过
                                                    currentPositionCrop.width+(cropWidth-value.translation.width)/2 <= imageDisplayWidth/2 &&
                                                    //防止左边超过
                                                    currentPositionCrop.width-(cropWidth-value.translation.width)/2 >= -imageDisplayWidth/2 {
                                                    currentPositionY.width = value.translation.width + newPositionY.width
                                                    //相邻的角
                                                    currentPositionYS.width = value.translation.width + newPositionYS.width
                                                    currentPositionYS.height = -value.translation.width/modeRatio/2 + newPositionYS.height
                                                    
                                                    currentPositionYX.width = value.translation.width + newPositionYX.width
                                                    currentPositionYX.height = value.translation.width/modeRatio/2 + newPositionYX.height
                                                    //不相邻的角
                                                    currentPositionZS.height = -value.translation.width/modeRatio/2 + newPositionZS.height
                                                    currentPositionZX.height = value.translation.width/modeRatio/2 + newPositionZX.height
                                                    //相邻的边
                                                    currentPositionS.width = value.translation.width/2 + newPositionS.width
                                                    currentPositionS.height = -value.translation.width/modeRatio/2 + newPositionS.height
                                                    currentPositionX.width = value.translation.width/2 + newPositionX.width
                                                    currentPositionX.height = value.translation.width/modeRatio/2 + newPositionX.height
                                                    //裁剪器部分
                                                    currentPositionCrop.width = value.translation.width/2 + newPositionCrop.width
                                                    cropWidthAdd = value.translation.width
                                                    cropHeightAdd = value.translation.width/modeRatio
                                                }
                                            }
                                        }
                                        .onEnded { value in
                                            operateOnEnd()
                                        }
                                )
                        }
                    }
                    
                    //Top-Leading
                    Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                        .font(.system(size: 12))
                        .foregroundColor(Color.pink)
                        .background(Circle().frame(width: 20, height: 20).foregroundColor(Color.white))
                        .offset(x: currentPositionZS.width - cropWidth/2, y: currentPositionZS.height - cropHeight/2)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    var modeRatio:CGFloat = 1
                                    if cropMode == 0{
                                        //自由模式
                                        //水平方向
                                        if cropWidth-value.translation.width > 40 && value.translation.width+newPositionZS.width > -imageDisplayWidth/2+cropWidth/2 {
                                            currentPositionZS.width = value.translation.width + newPositionZS.width
                                            currentPositionZX.width = value.translation.width + newPositionZX.width
                                            //相邻的边
                                            currentPositionS.width = value.translation.width/2 + newPositionS.width
                                            currentPositionZ.width = value.translation.width + newPositionZ.width
                                            //不相邻的边
                                            currentPositionX.width = value.translation.width/2 + newPositionX.width
                                            //裁剪器部分
                                            currentPositionCrop.width = value.translation.width/2 + newPositionCrop.width
                                            cropWidthAdd = -value.translation.width
                                        }
                                        //垂直方向
                                        if cropHeight-value.translation.height > 40 && value.translation.height+newPositionZS.height > -imageDisplayHeight/2+cropHeight/2 {
                                            currentPositionZS.height = value.translation.height + newPositionZS.height
                                            currentPositionYS.height = value.translation.height + newPositionYS.height
                                            //相邻的边
                                            currentPositionS.height = value.translation.height + newPositionS.height
                                            currentPositionZ.height = value.translation.height/2 + newPositionZ.height
                                            //不相邻的边
                                            currentPositionY.height = value.translation.height/2 + newPositionY.height
                                            //裁剪器部分
                                            currentPositionCrop.height = value.translation.height/2 + newPositionCrop.height
                                            cropHeightAdd = -value.translation.height
                                        }
                                    }else{
                                        if cropMode == 1 {
                                            if cropRatioIndex >= 0 && cropRatioIndex < cropRatios.count {
                                                modeRatio = cropRatios[cropRatioIndex].getRatioRevert()
                                            }
                                        }
                                        if (cropWidth-value.translation.width > 40 || cropHeight-value.translation.width*modeRatio > 40) &&
                                            //防止上边超过————这里要注意有负号
                                            value.translation.height + newPositionZS.height >= -imageDisplayHeight/2+cropHeight/2 &&
                                            //防止左边超过
                                            currentPositionCrop.width-(cropWidth-value.translation.width)/2 >= -imageDisplayWidth/2 {
                                            
                                            currentPositionZS.width = value.translation.width + newPositionZS.width
                                            currentPositionZS.height = value.translation.width*modeRatio + newPositionZS.height
                                            //相邻的角
                                            currentPositionZX.width = value.translation.width + newPositionZX.width
                                            currentPositionYS.height = value.translation.width*modeRatio + newPositionYS.height
                                            //相邻的边
                                            currentPositionS.width = value.translation.width/2 + newPositionS.width
                                            currentPositionS.height = value.translation.width*modeRatio + newPositionS.height
                                            currentPositionZ.width = value.translation.width + newPositionZ.width
                                            currentPositionZ.height = value.translation.width/2*modeRatio + newPositionZ.height
                                            //不相邻的边
                                            currentPositionX.width = value.translation.width/2 + newPositionX.width
                                            currentPositionY.height = value.translation.width/2*modeRatio + newPositionY.height
                                            //裁剪器部分
                                            currentPositionCrop.width = value.translation.width/2 + newPositionCrop.width
                                            currentPositionCrop.height = value.translation.width/2*modeRatio + newPositionCrop.height
                                            cropWidthAdd = -value.translation.width
                                            cropHeightAdd = -value.translation.width*modeRatio
                                        }
                                    }
                                }
                                .onEnded { value in
                                    operateOnEnd()
                                }
                        )
                    
                    //Bottom-Leading
                    Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                        .font(.system(size: 12))
                        .foregroundColor(Color.pink)
                        .background(Circle().frame(width: 20, height: 20).foregroundColor(Color.white))
                        .offset(x: currentPositionZX.width - cropWidth/2, y: currentPositionZX.height + cropHeight/2)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    var modeRatio:CGFloat = 1
                                    
                                    if cropMode == 0{
                                        if cropWidth-value.translation.width > 40 && value.translation.width+newPositionZX.width > -imageDisplayWidth/2+cropWidth/2{
                                            currentPositionZX.width = value.translation.width + newPositionZX.width
                                            currentPositionZS.width = value.translation.width + newPositionZS.width
                                            //相邻的边
                                            currentPositionZ.width = value.translation.width + newPositionZ.width
                                            currentPositionX.width = value.translation.width/2 + newPositionX.width
                                            //不相邻的边
                                            currentPositionS.width = value.translation.width/2 + newPositionX.width
                                            
                                            currentPositionCrop.width = value.translation.width/2 + newPositionCrop.width
                                            cropWidthAdd = -value.translation.width
                                        }
                                        
                                        if cropHeight+value.translation.height > 40 && value.translation.height+newPositionZX.height < imageDisplayHeight/2-cropHeight/2 {
                                            currentPositionZX.height = value.translation.height + newPositionZX.height
                                            
                                            currentPositionYX.height = value.translation.height + newPositionYX.height
                                            
                                            currentPositionZ.height = value.translation.height/2 + newPositionZ.height
                                            currentPositionX.height = value.translation.height + newPositionX.height
                                            
                                            currentPositionY.height = value.translation.height/2 + newPositionY.height
                                            
                                            currentPositionCrop.height = value.translation.height/2 + newPositionCrop.height
                                            cropHeightAdd = value.translation.height
                                        }
                                    }else{
                                        if cropMode == 1 {
                                            if cropRatioIndex >= 0 && cropRatioIndex < cropRatios.count {
                                                modeRatio = cropRatios[cropRatioIndex].getRatioRevert()
                                            }
                                        }
                                        if (cropWidth-value.translation.width > 40 || cropHeight-value.translation.width*modeRatio > 40) &&
                                            //防止下边超过
                                            -value.translation.width*modeRatio + newPositionZX.height <= imageDisplayHeight/2-cropHeight/2 &&
                                            //防止左边超过
                                            currentPositionCrop.width-(cropWidth-value.translation.width)/2 >= -imageDisplayWidth/2 {
                                            
                                            currentPositionZX.width = value.translation.width + newPositionZX.width
                                            currentPositionZX.height = -value.translation.width*modeRatio + newPositionZX.height
                                            
                                            currentPositionZS.width = value.translation.width + newPositionZS.width
                                            currentPositionYX.height = -value.translation.width*modeRatio + newPositionYX.height
                                            //相邻的边
                                            currentPositionZ.width = value.translation.width + newPositionZ.width
                                            currentPositionZ.height = -value.translation.width/2*modeRatio + newPositionZ.height
                                            
                                            currentPositionX.width = value.translation.width/2 + newPositionX.width
                                            currentPositionX.height = -value.translation.width*modeRatio + newPositionX.height
                                            
                                            //不相邻的边
                                            currentPositionY.height = -value.translation.width/2*modeRatio + newPositionY.height
                                            currentPositionS.width = value.translation.width/2 + newPositionX.width
                                            
                                            currentPositionCrop.width = value.translation.width/2 + newPositionCrop.width
                                            currentPositionCrop.height = -value.translation.width/2*modeRatio + newPositionCrop.height
                                            cropWidthAdd = -value.translation.width
                                            cropHeightAdd = -value.translation.width*modeRatio
                                        }
                                    }
                                }
                                .onEnded { value in
                                    operateOnEnd()
                                }
                        )
                    
                    //Bottom-Trailing
                    Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                        .font(.system(size: 12))
                        .foregroundColor(Color.pink)
                        .background(Circle().frame(width: 20, height: 20).foregroundColor(Color.white))
                        .offset(x: currentPositionYX.width + cropWidth/2, y: currentPositionYX.height + cropHeight/2)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    var modeRatio:CGFloat = 1
                                    
                                    if cropMode == 0{
                                        if cropWidth+value.translation.width > 40 && value.translation.width+newPositionYX.width < imageDisplayWidth/2-cropWidth/2{
                                            currentPositionYX.width = value.translation.width + newPositionYX.width
                                            currentPositionYS.width = value.translation.width + newPositionYS.width
                                            //相邻的边
                                            currentPositionX.width = value.translation.width/2 + newPositionX.width
                                            currentPositionY.width = value.translation.width + newPositionY.width
                                            //不相邻的边
                                            currentPositionS.width = value.translation.width/2 + newPositionX.width
                                            
                                            currentPositionCrop.width = value.translation.width/2 + newPositionCrop.width
                                            cropWidthAdd = value.translation.width
                                        }
                                        
                                        if cropHeight+value.translation.height > 40 && value.translation.height+newPositionYX.height < imageDisplayHeight/2-cropHeight/2{
                                            currentPositionYX.height = value.translation.height + newPositionYX.height
                                            currentPositionZX.height = value.translation.height + newPositionZX.height
                                            
                                            currentPositionX.height = value.translation.height + newPositionX.height
                                            currentPositionY.height = value.translation.height/2 + newPositionY.height
                                            
                                            currentPositionZ.height = value.translation.height/2 + newPositionZ.height
                                            
                                            currentPositionCrop.height = value.translation.height/2 + newPositionCrop.height
                                            cropHeightAdd = value.translation.height
                                        }
                                    }else{
                                        if cropMode == 1 {
                                            if cropRatioIndex >= 0 && cropRatioIndex < cropRatios.count {
                                                modeRatio = cropRatios[cropRatioIndex].getRatioRevert()
                                            }
                                        }
                                        if (cropWidth+value.translation.width > 40 || cropHeight+value.translation.width*modeRatio > 40) &&
                                            //防止下边超过
                                            value.translation.width*modeRatio + newPositionYX.height <= imageDisplayHeight/2-cropHeight/2 &&
                                            //防止右边超过
                                            currentPositionCrop.width+(cropWidth+value.translation.width)/2 <= imageDisplayWidth/2 {
                                            
                                            currentPositionYX.width = value.translation.width + newPositionYX.width
                                            currentPositionYX.height = value.translation.width*modeRatio + newPositionYX.height
                                            
                                            currentPositionYS.width = value.translation.width + newPositionYS.width
                                            currentPositionZX.height = value.translation.width*modeRatio + newPositionZX.height
                                            
                                            //相邻的边
                                            currentPositionX.width = value.translation.width/2 + newPositionX.width
                                            currentPositionX.height = value.translation.width*modeRatio + newPositionX.height
                                            
                                            currentPositionY.width = value.translation.width + newPositionY.width
                                            currentPositionY.height = value.translation.width/2*modeRatio + newPositionY.height
                                            
                                            //不相邻的边
                                            currentPositionS.width = value.translation.width/2 + newPositionS.width
                                            currentPositionZ.height = value.translation.width/2*modeRatio + newPositionZ.height
                                            
                                            currentPositionCrop.width = value.translation.width/2 + newPositionCrop.width
                                            currentPositionCrop.height = value.translation.width/2*modeRatio + newPositionCrop.height
                                            cropWidthAdd = value.translation.width
                                            cropHeightAdd = value.translation.width*modeRatio
                                        }
                                    }
                                }
                                .onEnded { value in
                                    operateOnEnd()
                                }
                        )
                    
                    //Bottom-Topping
                    Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                        .font(.system(size: 12))
                        .foregroundColor(Color.pink)
                        .background(Circle().frame(width: 20, height: 20).foregroundColor(Color.white))
                        .offset(x: currentPositionYS.width + cropWidth/2, y: currentPositionYS.height - cropHeight/2)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    var modeRatio:CGFloat = 1
                                    
                                    if cropMode == 0{
                                        if cropWidth+value.translation.width > 40 && value.translation.width+newPositionYS.width < imageDisplayWidth/2-cropWidth/2{
                                            currentPositionYS.width = value.translation.width + newPositionYS.width
                                            currentPositionYX.width = value.translation.width + newPositionYX.width
                                            //相邻的边
                                            currentPositionY.width = value.translation.width + newPositionY.width
                                            currentPositionS.width = value.translation.width/2 + newPositionX.width
                                            //不相邻的边
                                            currentPositionX.width = value.translation.width/2 + newPositionX.width
                                            
                                            currentPositionCrop.width = value.translation.width/2 + newPositionCrop.width
                                            cropWidthAdd = value.translation.width
                                        }
                                        
                                        if cropHeight-value.translation.height > 40 && -value.translation.height+newPositionYS.height < imageDisplayHeight/2-cropHeight/2{
                                            currentPositionYS.height = value.translation.height + newPositionYS.height
                                            currentPositionZS.height = value.translation.height + newPositionZS.height
                                            
                                            currentPositionY.height = value.translation.height/2 + newPositionY.height
                                            currentPositionS.height = value.translation.height + newPositionX.height
                                            
                                            currentPositionZ.height = value.translation.height/2 + newPositionZ.height
                                            
                                            currentPositionCrop.height = value.translation.height/2 + newPositionCrop.height
                                            cropHeightAdd = -value.translation.height
                                        }
                                    }else{
                                        if cropMode == 1 {
                                            if cropRatioIndex >= 0 && cropRatioIndex < cropRatios.count {
                                                modeRatio = cropRatios[cropRatioIndex].getRatioRevert()
                                            }
                                        }
                                        if (cropWidth+value.translation.width > 40 || cropHeight+value.translation.width*modeRatio > 40) &&
                                            //防止上边超过
                                            -value.translation.width*modeRatio + newPositionZS.height >= -imageDisplayHeight/2+cropHeight/2 &&
                                            //防止右边超过
                                            currentPositionCrop.width+(cropWidth+value.translation.width)/2 <= imageDisplayWidth/2 {
                                            
                                            currentPositionYS.width = value.translation.width + newPositionYS.width
                                            currentPositionYS.height = -value.translation.width*modeRatio + newPositionYS.height
                                            
                                            currentPositionYX.width = value.translation.width + newPositionYX.width
                                            currentPositionZS.height = -value.translation.width*modeRatio + newPositionZS.height
                                            
                                            //相邻的边
                                            currentPositionY.width = value.translation.width + newPositionY.width
                                            currentPositionY.height = -value.translation.width/2*modeRatio + newPositionY.height
                                            
                                            currentPositionS.width = value.translation.width/2 + newPositionX.width
                                            currentPositionS.height = -value.translation.width*modeRatio + newPositionX.height
                                            
                                            //不相邻的边
                                            currentPositionX.width = value.translation.width/2 + newPositionX.width
                                            currentPositionZ.height = -value.translation.width/2*modeRatio + newPositionZ.height
                                            
                                            currentPositionCrop.width = value.translation.width/2 + newPositionCrop.width
                                            currentPositionCrop.height = -value.translation.width/2*modeRatio + newPositionCrop.height
                                            cropWidthAdd = value.translation.width
                                            cropHeightAdd = value.translation.width*modeRatio
                                        }
                                    }
                                }
                                .onEnded { value in
                                    operateOnEnd()
                                }
                        )
                }
                
                
                HStack {
                    Button (action : {
                        cropMode = 0
                        cropRatioIndex = -1 // reset
                    }) {
                        HStack {
                            Image(systemName: "highlighter")
                            Text("Custom")
                        }
                    }
                    
                    ForEach(Array(cropRatios.enumerated()), id: \.offset) { ratioIndex, ratio in
                        Button (action : {
                            cropMode = 1
                            cropRatioIndex = ratioIndex
                            
                            cropHeight = cropWidth * ratio.getRatioRevert()
                            if cropWidth > cropHeight{
                                cropWidth = cropHeight * ratio.getRatio()
                            }else{
                                cropHeight = cropWidth * ratio.getRatioRevert()
                            }
                            
                            if currentPositionCrop.width >= imageDisplayWidth/2 - cropWidth/2{
                                currentPositionCrop.width = imageDisplayWidth/2 - cropWidth/2
                                operateOnEnd()
                            }else if currentPositionCrop.width <= -imageDisplayWidth/2 + cropWidth/2{
                                currentPositionCrop.width = -imageDisplayWidth/2 + cropWidth/2
                                operateOnEnd()
                            }
                        }) {
                            HStack {
                                Image(systemName: ratio.image)
                                Text(ratio.title)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button (action : {
                        //由于CGRect是先到坐标再开始生成的，所以要这样减去剪裁栏的部分
                        let rect = CGRect(x: imageDisplayWidth/2 + currentPositionCrop.width - cropWidth/2,
                                          y: imageDisplayHeight/2 + currentPositionCrop.height - cropHeight/2,
                                          width: cropWidth,
                                          height: cropHeight)
                        croppedImage = SWCropImageInternal(inputImage, toRect: rect, viewWidth: imageDisplayWidth, viewHeight: imageDisplayHeight)!
                        
                    }) {
                        HStack {
                            Image(systemName: "crop")
                            Text("Crop")
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    func operateOnEnd(){
        cropWidth = cropWidth + cropWidthAdd
        cropHeight = cropHeight + cropHeightAdd
        cropWidthAdd = 0
        cropHeightAdd = 0
        
        //Conners
        currentPositionZS = currentPositionCrop
        currentPositionZX = currentPositionCrop
        currentPositionYX = currentPositionCrop
        currentPositionYS = currentPositionCrop
        
        //Sides
        currentPositionS = currentPositionCrop
        currentPositionZ = currentPositionCrop
        currentPositionX = currentPositionCrop
        currentPositionY = currentPositionCrop
        
        self.newPositionCrop = self.currentPositionCrop
        self.newPositionZS = self.currentPositionZS
        self.newPositionZX = self.currentPositionZX
        self.newPositionYX = self.currentPositionYX
        self.newPositionYS = self.currentPositionYS
        self.newPositionS = self.currentPositionS
        self.newPositionZ = self.currentPositionZ
        self.newPositionX = self.currentPositionX
        self.newPositionY = self.currentPositionY
    }
}
