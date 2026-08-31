//
//  QRPayload.swift
//  QRKit
//
//  Created by David Sherlock on 2026.
//
//  The things people actually put in QR codes, as typed values that
//  encode themselves correctly. The escaping rules are where hand-rolled
//  payloads go wrong — a semicolon in a Wi-Fi password silently truncates
//  the credentials — so they live here once, tested to the exact string.
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

    /// The exact string the code carries.
    public var encoded: String {
        switch self {
        case .text(let value):
            return value
        case .wifi(let ssid, let password, let security, let hidden):
            var fields = "WIFI:T:\(security.rawValue);S:\(Self.wifiEscaped(ssid));"
            if security != .open, let password { fields += "P:\(Self.wifiEscaped(password));" }
            if hidden { fields += "H:true;" }
            return fields + ";"
        case .vCard(let name, let phone, let email, let organization, let url):
            var lines = ["BEGIN:VCARD", "VERSION:3.0",
                         "FN:\(Self.vCardEscaped(name))",
                         "N:\(Self.vCardEscaped(name));;;;"]
            if let phone { lines.append("TEL:\(Self.vCardEscaped(phone))") }
            if let email { lines.append("EMAIL:\(Self.vCardEscaped(email))") }
            if let organization { lines.append("ORG:\(Self.vCardEscaped(organization))") }
            if let url { lines.append("URL:\(Self.vCardEscaped(url))") }
            lines.append("END:VCARD")
            return lines.joined(separator: "\r\n")
        case .mailto(let address, let subject):
            let query = subject.flatMap { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) }
            return "mailto:\(address)" + (query.map { "?subject=\($0)" } ?? "")
        case .tel(let number):
            return "tel:\(number)"
        case .sms(let number, let body):
            let query = body.flatMap { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) }
            return "sms:\(number)" + (query.map { "?body=\($0)" } ?? "")
        case .geo(let latitude, let longitude):
            return "geo:\(latitude),\(longitude)"
        }
    }

    /// Wi-Fi payload escaping: `\` `;` `,` `:` and `"` take a backslash.
    static func wifiEscaped(_ value: String) -> String {
        var out = ""
        for character in value {
            if "\\;,:\"".contains(character) { out.append("\\") }
            out.append(character)
        }
        return out
    }

    /// vCard escaping: `\` `;` `,` take a backslash; newlines become `\n`.
    static func vCardEscaped(_ value: String) -> String {
        var out = ""
        for character in value {
            switch character {
            case "\\", ";", ",": out.append("\\"); out.append(character)
            case "\n": out.append("\\n")
            case "\r": continue
            default: out.append(character)
            }
        }
        return out
    }
}
