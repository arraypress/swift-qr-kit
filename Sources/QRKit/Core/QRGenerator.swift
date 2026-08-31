//
//  QRGenerator.swift
//  QRKit
//
//  Created by David Sherlock on 2026.
//
//  Payload in, code out — as a module matrix, a crisp bitmap, or a PNG.
//  Core Image generates the modules; the pixels are drawn from the matrix
//  here, because scaling the generator's one-pixel-per-module output
//  through a sampler blurs the edges that make a code scannable.
//

import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Makes QR codes.
public enum QRGenerator {

    /// The code's modules — `true` is a dark module. Square, version-sized
    /// (21×21 upward), without the quiet zone; rendering adds it.
    public static func matrix(for payload: QRPayload, level: QRCorrectionLevel = .medium) throws -> [[Bool]] {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { throw QRError.generationFailed }
        filter.setValue(Data(payload.encoded.utf8), forKey: "inputMessage")
        filter.setValue(level.rawValue, forKey: "inputCorrectionLevel")
        guard let image = filter.outputImage else { throw QRError.generationFailed }
        let width = Int(image.extent.width), height = Int(image.extent.height)
        guard width > 0, width == height else { throw QRError.generationFailed }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = CIContext()
        context.render(image, toBitmap: &pixels, rowBytes: width * 4,
                       bounds: image.extent, format: .RGBA8,
                       colorSpace: CGColorSpaceCreateDeviceRGB())
        var grid = (0..<height).map { row in
            (0..<width).map { column in pixels[(row * width + column) * 4] < 128 }
        }
        // CIQRCodeGenerator pads a one-module light border. Trim any uniform
        // light ring so callers get the bare code; rendering adds the real
        // four-module quiet zone itself.
        while grid.count > 1,
              grid.first!.allSatisfy({ !$0 }), grid.last!.allSatisfy({ !$0 }),
              grid.allSatisfy({ !$0.first! && !$0.last! }) {
            grid.removeFirst(); grid.removeLast()
            for index in grid.indices { grid[index].removeFirst(); grid[index].removeLast() }
        }
        return grid
    }

    /// The code as a bitmap: every module an exact block of pixels, a
    /// four-module quiet zone all round, and the colours as given.
    public static func image(for payload: QRPayload, size: Int = 512,
                             level: QRCorrectionLevel = .medium,
                             foreground: QRColor = .black,
                             background: QRColor = .white) throws -> CGImage {
        let modules = try matrix(for: payload, level: level)
        return try MatrixRenderer.image(from: modules, size: size, quietZone: 4,
                                        foreground: foreground, background: background)
    }

    /// Writes the code as a PNG.
    public static func writePNG(_ payload: QRPayload, to url: URL, size: Int = 512,
                                level: QRCorrectionLevel = .medium,
                                foreground: QRColor = .black,
                                background: QRColor = .white) throws {
        let image = try self.image(for: payload, size: size, level: level,
                                   foreground: foreground, background: background)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw QRError.renderFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw QRError.renderFailed }
    }

    /// The code as an SVG document — the same modules, quiet zone and
    /// colours as the bitmap, but resolution-free for print.
    public static func svg(for payload: QRPayload, size: Int = 512,
                           level: QRCorrectionLevel = .medium,
                           foreground: QRColor = .black,
                           background: QRColor = .white) throws -> String {
        MatrixRenderer.svg(from: try matrix(for: payload, level: level), size: size,
                           quietZone: 4, foreground: foreground, background: background)
    }
}
