//
//  QRColor.swift
//  QRKit
//
//  Created by David Sherlock on 2026.
//

/// A colour as plain values, so options stay `Sendable`.
public struct QRColor: Sendable, Equatable {
    /// Channels `0…1`.
    public var red, green, blue, alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    /// The classic dark module.
    public static let black = QRColor(red: 0, green: 0, blue: 0)
    /// The classic ground.
    public static let white = QRColor(red: 1, green: 1, blue: 1)
}
