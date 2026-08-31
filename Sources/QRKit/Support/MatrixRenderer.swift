//
//  MatrixRenderer.swift
//  QRKit
//
//  Created by David Sherlock on 2026.
//
//  A module matrix drawn to pixels — split from the generator so the
//  drawing (module size arithmetic, quiet zone, colours) is testable on a
//  hand-made matrix without Core Image in the loop.
//

import CoreGraphics
import Foundation

/// Draws boolean module grids as crisp bitmaps.
enum MatrixRenderer {

    /// The matrix at `size`×`size` pixels: whole-pixel modules, the given
    /// quiet zone in modules, centred by rounding the module size DOWN so
    /// edges never blur.
    static func image(from modules: [[Bool]], size: Int, quietZone: Int,
                      foreground: QRColor, background: QRColor) throws -> CGImage {
        let count = modules.count
        guard count > 0, size > 0 else { throw QRError.renderFailed }
        let total = count + quietZone * 2
        let moduleSize = max(1, size / total)
        let side = moduleSize * total
        guard let context = CGContext(data: nil, width: side, height: side,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw QRError.renderFailed
        }
        context.setFillColor(CGColor(srgbRed: background.red, green: background.green, blue: background.blue, alpha: background.alpha))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        context.setFillColor(CGColor(srgbRed: foreground.red, green: foreground.green, blue: foreground.blue, alpha: foreground.alpha))
        for (rowIndex, row) in modules.enumerated() {
            for (columnIndex, dark) in row.enumerated() where dark {
                // The matrix is top-down; CGContext is bottom-up.
                let x = (quietZone + columnIndex) * moduleSize
                let y = side - (quietZone + rowIndex + 1) * moduleSize
                context.fill(CGRect(x: x, y: y, width: moduleSize, height: moduleSize))
            }
        }
        guard let image = context.makeImage() else { throw QRError.renderFailed }
        return image
    }

    /// The matrix as an SVG document: the same whole-unit modules and
    /// quiet zone as the bitmap, but resolution-free. Dark modules merge
    /// into horizontal runs so the path stays small, and the pixel size
    /// follows the bitmap's whole-pixel rounding so the two outputs
    /// always agree.
    static func svg(from modules: [[Bool]], size: Int, quietZone: Int,
                    foreground: QRColor, background: QRColor) -> String {
        let count = modules.count
        let total = count + quietZone * 2
        let moduleSize = max(1, size / max(1, total))
        let side = moduleSize * total
        var path = ""
        for (rowIndex, row) in modules.enumerated() {
            var column = 0
            while column < row.count {
                guard row[column] else { column += 1; continue }
                var run = 1
                while column + run < row.count, row[column + run] { run += 1 }
                path += "M\(quietZone + column) \(quietZone + rowIndex)h\(run)v1h-\(run)z"
                column += run
            }
        }
        return """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(side)" height="\(side)" viewBox="0 0 \(total) \(total)" shape-rendering="crispEdges">
        <rect width="\(total)" height="\(total)" fill="\(hex(background))"/>
        <path d="\(path)" fill="\(hex(foreground))"/>
        </svg>
        """
    }

    /// `#RRGGBB` for an SVG fill.
    static func hex(_ color: QRColor) -> String {
        func channel(_ value: Double) -> Int { Int((max(0, min(1, value)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", channel(color.red), channel(color.green), channel(color.blue))
    }
}
