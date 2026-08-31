//
//  ParsedPayload.swift
//  QRKit
//
//  Created by David Sherlock on 2026.
//
//  What a scanned string turned out to be — the shape only. The parsing
//  that produces one lives in Support/PayloadDecoding; the delegating
//  initialiser and ScannedCode's `parsed` live in Extensions.
//
//  This is a separate type from QRPayload because reading is lossier
//  than writing: a scanned Wi-Fi code may name no security type, and a
//  card from another phone carries fields at tolerances an encoder
//  never produces.
//

import Foundation

/// A scanned payload, decoded into its meaning.
public enum ParsedPayload: Sendable, Equatable {
    /// An http(s) link.
    case url(String)
    /// Anything that matched no richer form — carried verbatim.
    case text(String)
    /// Wi-Fi credentials. `security` is nil when the code names none.
    case wifi(ssid: String, password: String?, security: WifiSecurity?, hidden: Bool)
    /// A contact card (vCard, 2.1-ish through 3.0 tolerated).
    case contact(Contact)
    /// A calendar event.
    case event(Event)
    /// An email compose action.
    case email(to: String, cc: String?, subject: String?, body: String?)
    /// A phone number.
    case tel(String)
    /// A text message.
    case sms(number: String, body: String?)
    /// Coordinates.
    case geo(latitude: Double, longitude: Double)
    /// A WhatsApp chat link.
    case whatsapp(number: String, message: String?)
}
