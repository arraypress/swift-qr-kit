//
//  QRError.swift
//  QRKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What can go wrong making or reading a code.
public enum QRError: Error, LocalizedError, Sendable, Equatable {
    /// Core Image declined to generate — payload too large for a QR code.
    case generationFailed
    /// The file could not be read as an image.
    case unreadableImage(String)
    /// A bitmap could not be rendered.
    case renderFailed

    public var errorDescription: String? {
        switch self {
        case .generationFailed: return "the payload is too large to fit a QR code"
        case .unreadableImage(let path): return "\(path) is not an image that can be read"
        case .renderFailed: return "the code could not be rendered to pixels"
        }
    }
}
