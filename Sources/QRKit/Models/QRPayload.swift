//
//  QRPayload.swift
//  QRKit
//
//  Created by David Sherlock on 2026.
//
//  The things people actually put in QR codes, as typed values. This is
//  the vocabulary only — what a payload IS. How each one becomes the
//  exact string a code carries, escaping rules included, lives in
//  Support/PayloadEncoding and the Extensions file that delegates to it;
//  a model that also encodes itself is two jobs in one type.
//

import Foundation

/// A payload a QR code can carry.
public enum QRPayload: Sendable, Equatable {
    /// Plain text, or a URL — carried verbatim.
    case text(String)
    /// Wi-Fi credentials a phone camera joins directly.
    case wifi(ssid: String, password: String?, security: WifiSecurity, hidden: Bool)
    /// A contact card (vCard 3.0).
    case vCard(name: String, phone: String?, email: String?, organization: String?, url: String?)
    /// An email compose action.
    case mailto(String, subject: String?)
    /// A phone number to dial.
    case tel(String)
    /// A text message, optionally pre-filled.
    case sms(String, body: String?)
    /// A place, by coordinates.
    case geo(latitude: Double, longitude: Double)
}
