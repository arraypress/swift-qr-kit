//
//  PayloadEncoding.swift
//  QRKit
//
//  Created by David Sherlock on 2026.
//
//  Payloads as the exact strings a code carries. The escaping rules are
//  where hand-rolled payloads go wrong — a semicolon in a Wi-Fi password
//  silently truncates the credentials — so they live here once, as pure
//  functions a test can pin to the character without constructing a
//  model, and the model delegates.
//

import Foundation

/// String assembly and escaping for every payload the model offers.
enum PayloadEncoding {

    /// The `WIFI:` scheme phone cameras join from.
    static func wifi(ssid: String, password: String?, security: WifiSecurity, hidden: Bool) -> String {
        var fields = "WIFI:T:\(security.rawValue);S:\(wifiEscaped(ssid));"
        if security != .open, let password { fields += "P:\(wifiEscaped(password));" }
        if hidden { fields += "H:true;" }
        return fields + ";"
    }

    /// A vCard 3.0 with CRLF line ends, optional fields dropped not blanked.
    static func vCard(name: String, phone: String?, email: String?, organization: String?, url: String?) -> String {
        var lines = ["BEGIN:VCARD", "VERSION:3.0",
                     "FN:\(vCardEscaped(name))",
                     "N:\(vCardEscaped(name));;;;"]
        if let phone { lines.append("TEL:\(vCardEscaped(phone))") }
        if let email { lines.append("EMAIL:\(vCardEscaped(email))") }
        if let organization { lines.append("ORG:\(vCardEscaped(organization))") }
        if let url { lines.append("URL:\(vCardEscaped(url))") }
        lines.append("END:VCARD")
        return lines.joined(separator: "\r\n")
    }

    /// An email compose action, subject percent-encoded.
    static func mailto(_ address: String, subject: String?) -> String {
        "mailto:\(address)" + (percentQuery(subject).map { "?subject=\($0)" } ?? "")
    }

    /// A text message, body percent-encoded.
    static func sms(_ number: String, body: String?) -> String {
        "sms:\(number)" + (percentQuery(body).map { "?body=\($0)" } ?? "")
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
            // "\r\n" is ONE Character in Swift, so a Windows newline never
            // matches "\n" alone and would sail through untouched.
            case "\n", "\r\n": out.append("\\n")
            case "\r": continue
            default: out.append(character)
            }
        }
        return out
    }

    /// A query value percent-encoded, or nothing for nothing.
    static func percentQuery(_ value: String?) -> String? {
        value.flatMap { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) }
    }
}
