//
//  QRCorrectionLevel.swift
//  QRKit
//
//  Created by David Sherlock on 2026.
//

/// How much of the code can be damaged and still read.
///
/// Higher levels add redundancy and grow the code. `medium` is the
/// everyday choice; `high` suits codes that get printed small or worn.
public enum QRCorrectionLevel: String, CaseIterable, Sendable {
    /// ~7 % recoverable.
    case low = "L"
    /// ~15 % recoverable — the default.
    case medium = "M"
    /// ~25 % recoverable.
    case quartile = "Q"
    /// ~30 % recoverable.
    case high = "H"
}
