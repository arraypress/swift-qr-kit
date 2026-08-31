//
//  ScannedCode.swift
//  QRKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One machine-readable code found in an image.
public struct ScannedCode: Sendable, Equatable {
    /// What the code says.
    public let payload: String
    /// The barcode family — `QR`, `EAN13`, `Code128`, …
    public let symbology: String
    /// Where it sits, as fractions of the image with a TOP-LEFT origin —
    /// the same convention the fleet's other tools use.
    public let bounds: CGRect

    /// A scanned code.
    public init(payload: String, symbology: String, bounds: CGRect) {
        self.payload = payload
        self.symbology = symbology
        self.bounds = bounds
    }
}
