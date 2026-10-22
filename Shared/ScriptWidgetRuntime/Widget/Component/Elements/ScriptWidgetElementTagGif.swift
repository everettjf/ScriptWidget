import Foundation
import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import CryptoKit
import Darwin

final class ScriptWidgetGifSequence {
    let frames: [CGImage]
    let delays: [Double]
    let decodedBytes: Int
    let frameLimitFallback: Bool
    var duration: Double { delays.reduce(0,+) }
    init(frames: [CGImage], delays: [Double], decodedBytes: Int, frameLimitFallback: Bool) {
        self.frames = frames; self.delays = delays; self.decodedBytes = decodedBytes; self.frameLimitFallback = frameLimitFallback
    }
    func frameIndex(elapsed: Double) -> Int {
        guard elapsed.isFinite, elapsed > 0, duration > 0 else { return 0 }
        var time = elapsed.truncatingRemainder(dividingBy: duration)
        for (index, delay) in delays.enumerated() {
            if time < delay { return index }
            time -= delay
        }
        return 0
    }
}

/// GIF bytes and source canvas are checked before any pixel decode. Only bounded
/// thumbnails are retained; no third-party decoder or UIImage frame expansion.
enum ScriptWidgetGifPipeline {
    static let maximumInputBytes = 8 * 1_024 * 1_024
    static let maximumCanvasPixels = 1_048_576
    static let maximumFrameCount = 60
    static let maximumDecodedBytes = 4 * 1_024 * 1_024
    static let maximumPixelSize = 512
    private static let cache: NSCache<NSString, ScriptWidgetGifSequence> = {
        let value = NSCache<NSString, ScriptWidgetGifSequence>()
        value.totalCostLimit = maximumDecodedBytes; value.countLimit = 4
        return value
    }()
    static func removeAll() { cache.removeAllObjects() }
    static func sequence(at url: URL, animated: Bool) -> ScriptWidgetGifSequence? {
        guard url.isFileURL else { return nil }
        let fd = url.withUnsafeFileSystemRepresentation { path in path.map { Darwin.open($0,O_RDONLY | O_NOFOLLOW | O_NONBLOCK) } ?? -1 }
        guard fd >= 0 else { return nil }
        let handle = FileHandle(fileDescriptor:fd,closeOnDealloc:true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(fd,&info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_size > 0, info.st_size <= maximumInputBytes,
              let data = try? handle.read(upToCount:maximumInputBytes+1), data.count <= maximumInputBytes else { return nil }
        return sequence(data:data,animated:animated)
    }
    static func sequence(data: Data, animated: Bool) -> ScriptWidgetGifSequence? {
        guard !data.isEmpty, data.count <= maximumInputBytes else { return nil }
        let key = "\(SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined())|\(animated)" as NSString
        if let value = cache.object(forKey:key) { return value }
        guard let source = CGImageSourceCreateWithData(data as CFData,[kCGImageSourceShouldCache:false] as CFDictionary),
              CGImageSourceGetType(source) as String? == UTType.gif.identifier else { return nil }
        let sourceCount = CGImageSourceGetCount(source)
        guard sourceCount > 0 else { return nil }
        let fallback = animated && sourceCount > maximumFrameCount
        let count = animated && !fallback ? sourceCount : 1
        let edge = min(maximumPixelSize,Int(sqrt(Double(maximumDecodedBytes / (4 * count)))) / 16 * 16)
        var frames: [CGImage] = [], delays: [Double] = [], bytes = 0
        for index in 0..<count {
            guard let properties = CGImageSourceCopyPropertiesAtIndex(source,index,nil) as? [CFString:Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
                  let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
                  width.intValue > 0, height.intValue > 0, width.intValue <= maximumCanvasPixels / height.intValue else { return nil }
            let options: [CFString:Any] = [kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceCreateThumbnailWithTransform:true,
                kCGImageSourceThumbnailMaxPixelSize:edge,kCGImageSourceShouldCacheImmediately:true,kCGImageSourceShouldCache:false]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source,index,options as CFDictionary),
                  image.width <= edge, image.height <= edge, image.bytesPerRow <= maximumDecodedBytes / max(1,image.height) else { return nil }
            let cost = image.bytesPerRow * image.height
            guard cost <= maximumDecodedBytes - bytes else { return nil }
            let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString:Any]
            let rawDelay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber)?.doubleValue ?? (gif?[kCGImagePropertyGIFDelayTime] as? NSNumber)?.doubleValue ?? 0.1
            guard rawDelay.isFinite, rawDelay >= 0, rawDelay <= 655.35 else { return nil }
            frames.append(image); delays.append(rawDelay < 0.011 ? 0.1 : rawDelay); bytes += cost
        }
        let value = ScriptWidgetGifSequence(frames:frames,delays:delays,decodedBytes:bytes,frameLimitFallback:fallback)
        cache.setObject(value,forKey:key,cost:bytes); return value
    }
}

struct DynamicGifView: View {
    let gifPath: URL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var luminanceReduced
    @Environment(\.scriptWidgetVisualAccessibility) private var preview
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.scriptWidgetAnimationPreview) private var animationPreview
    private var animated: Bool {
        #if os(macOS)
        return false
        #else
        return !(preview.reduceMotion ?? reduceMotion) && !luminanceReduced && referenceDate == nil && (animationPreview.live ?? (scenePhase == .active))
        #endif
    }
    var referenceDate: Date? = nil
    var body: some View {
        if let sequence = ScriptWidgetGifPipeline.sequence(at:gifPath,animated:animated), let first = sequence.frames.first {
            if sequence.frames.count == 1 {
                Image(decorative:first,scale:1).resizable().aspectRatio(contentMode:.fit)
            } else {
                GeometryReader { proxy in
                    ScriptWidgetAnimationFrame(referenceDate: referenceDate) { _, elapsed in
                        Image(decorative:sequence.frames[sequence.frameIndex(elapsed:elapsed)],scale:1).resizable().aspectRatio(contentMode:.fit)
                            .frame(width:proxy.size.width,height:proxy.size.height)
                    }
                }
            }
        } else { Text("GIF unavailable") }
    }
}

class ScriptWidgetElementTagGif {
    static func buildView(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext) -> AnyView {

        if let file = element.getPropString("file") {
            if let path = context.package.getGifFile(file) {
                return AnyView(
                    DynamicGifView(gifPath: path, referenceDate: context.animationDate)
                        .modifier(ScriptWidgetAttributeImageModifier(element, context))
                        .modifier(ScriptWidgetAttributeFontModifier(element))
                        .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
                )
            } else {
                return AnyView(
                    Text("file not found")
                        .modifier(ScriptWidgetAttributeImageModifier(element, context))
                        .modifier(ScriptWidgetAttributeFontModifier(element))
                        .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
                )
            }
        }

        // default
        return AnyView(
            Text("file not specified")
                .modifier(ScriptWidgetAttributeImageModifier(element, context))
                .modifier(ScriptWidgetAttributeFontModifier(element))
                .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
        )
    }
}
