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
}
