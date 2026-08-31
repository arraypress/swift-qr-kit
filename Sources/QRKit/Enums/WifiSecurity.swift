//
//  WifiSecurity.swift
//  QRKit
//
//  Created by David Sherlock on 2026.
//

/// The security field of a Wi-Fi QR payload.
public enum WifiSecurity: String, CaseIterable, Sendable {
    /// WPA/WPA2/WPA3 — what nearly every network is.
    case wpa = "WPA"
    /// Legacy WEP.
    case wep = "WEP"
    /// An open network; the payload carries no password.
    case open = "nopass"
}
