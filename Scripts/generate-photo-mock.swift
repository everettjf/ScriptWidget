// Original geometric preview artwork. Run from the repository root with swift.
import AppKit
import ImageIO
import UniformTypeIdentifiers
let variant = CommandLine.arguments.count > 2 ? (Int(CommandLine.arguments[2]) ?? 0) : 0
func themed(_ color: NSColor) -> CGColor {
    guard variant != 0, let rgb = color.usingColorSpace(.deviceRGB) else { return color.cgColor }
    return NSColor(calibratedHue: (rgb.hueComponent + CGFloat(variant) * 0.16).truncatingRemainder(dividingBy: 1), saturation: rgb.saturationComponent, brightness: rgb.brightnessComponent, alpha: 1).cgColor
}
let w=384,h=256
let space=CGColorSpaceCreateDeviceRGB()
let c=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:space,bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
c.setFillColor(themed(NSColor(calibratedRed:0.86,green:0.94,blue:0.96,alpha:1)));c.fill(CGRect(x:0,y:0,width:w,height:h))
c.setFillColor(themed(NSColor(calibratedRed:0.98,green:0.81,blue:0.46,alpha:1)));c.fillEllipse(in:CGRect(x:280,y:160,width:48,height:48))
for (points,color) in [([CGPoint(x:0,y:100),CGPoint(x:120,y:210),CGPoint(x:300,y:10),CGPoint(x:0,y:0)],NSColor(calibratedRed:0.48,green:0.69,blue:0.65,alpha:1)),([CGPoint(x:100,y:0),CGPoint(x:280,y:174),CGPoint(x:384,y:75),CGPoint(x:384,y:0)],NSColor(calibratedRed:0.26,green:0.52,blue:0.48,alpha:1))] {
c.beginPath();c.addLines(between:points);c.closePath();c.setFillColor(themed(color));c.fillPath()
}
let data=NSMutableData();let d=CGImageDestinationCreateWithData(data,UTType.jpeg.identifier as CFString,1,nil)!
CGImageDestinationAddImage(d,c.makeImage()!,[kCGImageDestinationLossyCompressionQuality:0.7] as CFDictionary);CGImageDestinationFinalize(d)
try (data as Data).write(to:URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Web/preview-engine/test/fixtures/photo-landscape.jpg"))
