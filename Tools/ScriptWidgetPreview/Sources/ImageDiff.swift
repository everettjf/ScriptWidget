import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Pixel comparison with the same rule as Web/preview-engine/scripts/
/// compare-snapshots.mjs: a pixel differs when any channel moves by > 48.
enum ImageDiff {
    struct Result {
        let percent: Double
        let image: CGImage?
        let sizeMatches: Bool
    }

    static func rgba(_ image: CGImage) -> (Int, Int, [UInt8]) {
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return (width, height, pixels)
    }

    static func compare(_ native: CGImage, _ web: CGImage) -> Result {
        let (nw, nh, a) = rgba(native)
        let (ww, wh, b) = rgba(web)
        let width = min(nw, ww), height = min(nh, wh)
        guard width > 0, height > 0 else { return Result(percent: 100, image: nil, sizeMatches: false) }
        var diff = [UInt8](repeating: 255, count: width * height * 4)
        var different = 0
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * nw + x) * 4, j = (y * ww + x) * 4, k = (y * width + x) * 4
                let delta = max(abs(Int(a[i]) - Int(b[j])), abs(Int(a[i + 1]) - Int(b[j + 1])), abs(Int(a[i + 2]) - Int(b[j + 2])))
                if delta > 48 { different += 1; diff[k + 1] = 0; diff[k + 2] = 0 }
                else { let shade = UInt8(255 - delta); diff[k + 1] = shade; diff[k + 2] = shade }
            }
        }
        let image = diff.withUnsafeMutableBytes { buffer -> CGImage? in
            CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
        return Result(percent: Double(different) * 100 / Double(width * height), image: image, sizeMatches: nw == ww && nh == wh)
    }

    static func writePNG(_ image: CGImage, to url: URL) {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }
}
