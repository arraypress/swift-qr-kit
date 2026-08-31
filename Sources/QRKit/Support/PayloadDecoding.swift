//
//  PayloadDecoding.swift
//  QRKit
//
//  Created by David Sherlock on 2026.
//
//  The mirror of PayloadEncoding: scanned strings back into their
//  meaning, as pure functions. Reading tolerates what other encoders
//  produce — vCard 2.1 parameter style, LF-only line ends, folded
//  continuation lines — because the code being scanned was rarely made
//  by this library.
//

import Foundation

/// Scanned strings decoded into ``ParsedPayload``s.
enum PayloadDecoding {

    /// What `raw` means. Never fails — anything unrecognised is `.text`.
    static func parse(_ raw: String) -> ParsedPayload {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = trimmed.uppercased()
        if upper.hasPrefix("WIFI:") { return wifi(trimmed) ?? .text(raw) }
        if upper.hasPrefix("BEGIN:VCARD") { return contact(trimmed) ?? .text(raw) }
        if upper.contains("BEGIN:VEVENT") { return event(trimmed) ?? .text(raw) }
        if upper.hasPrefix("MAILTO:") { return mailto(trimmed) }
        if upper.hasPrefix("TEL:") { return .tel(String(trimmed.dropFirst("tel:".count))) }
        if upper.hasPrefix("SMSTO:") { return smsto(trimmed) }
        if upper.hasPrefix("SMS:") { return sms(trimmed) }
        if upper.hasPrefix("GEO:") { return geo(trimmed) ?? .text(raw) }
        if upper.hasPrefix("HTTPS://WA.ME/") || upper.hasPrefix("HTTP://WA.ME/") { return whatsapp(trimmed) }
        if upper.hasPrefix("HTTP://") || upper.hasPrefix("HTTPS://") { return .url(trimmed) }
        return .text(raw)
    }

    // MARK: - Wi-Fi

    /// `WIFI:T:WPA;S:name;P:pass;H:true;;` with the escaping undone.
    private static func wifi(_ string: String) -> ParsedPayload? {
        var fields: [(String, String)] = []
        var key = "", value = "", inValue = false, escaped = false
        for character in string.dropFirst("WIFI:".count) {
            if escaped { value.append(character); escaped = false; continue }
            if inValue, character == "\\" { escaped = true; continue }
            if !inValue {
                if character == ":" { inValue = true }
                else if character == ";" { key = "" }
                else { key.append(character) }
            } else if character == ";" {
                fields.append((key.uppercased(), value)); key = ""; value = ""; inValue = false
            } else {
                value.append(character)
            }
        }
        if inValue { fields.append((key.uppercased(), value)) }
        var ssid: String?, password: String?, security: WifiSecurity?, hidden = false
        for (name, content) in fields {
            switch name {
            case "S": ssid = content
            case "P": password = content
            case "T": security = securityNamed(content)
            case "H": hidden = content.lowercased() == "true"
            default: break   // enterprise EAP fields and friends, dropped deliberately
            }
        }
        guard let ssid else { return nil }
        return .wifi(ssid: ssid, password: password, security: security, hidden: hidden)
    }

    private static func securityNamed(_ name: String) -> WifiSecurity? {
        switch name.uppercased() {
        case "WPA", "WPA2", "WPA3": return .wpa
        case "WEP": return .wep
        case "SAE": return .sae
        case "NOPASS", "": return .open
        default: return nil
        }
    }

    // MARK: - vCard

    private static func contact(_ string: String) -> ParsedPayload? {
        var card = Contact(givenName: "")
        var sawName = false
        var displayName: String?
        for line in unfoldedLines(string) {
            let (name, parameters, value) = property(line)
            switch name {
            case "N":
                let parts = splitUnescaped(value, on: ";").map(unescaped)
                card.familyName = parts.count > 0 ? parts[0] : ""
                card.givenName = parts.count > 1 ? parts[1] : ""
                sawName = true
            case "FN": displayName = unescaped(value)
            case "TEL": card.phones.append(.init(unescaped(value), label: label(in: parameters)))
            case "EMAIL": card.emails.append(.init(unescaped(value), label: label(in: parameters)))
            case "ORG": card.organization = unescaped(splitUnescaped(value, on: ";").first ?? value)
            case "TITLE": card.title = unescaped(value)
            case "ADR":
                let parts = splitUnescaped(value, on: ";").map(unescaped)
                func part(_ index: Int) -> String? {
                    index < parts.count && !parts[index].isEmpty ? parts[index] : nil
                }
                card.address = .init(street: part(2), city: part(3), region: part(4),
                                     postalCode: part(5), country: part(6))
            case "BDAY": card.birthday = birthday(value)
            case "URL": card.urls.append(unescaped(value))
            case "NOTE": card.note = unescaped(value)
            default: break   // PHOTO, categories, and the long tail — dropped
            }
        }
        if !sawName, let displayName {
            // FN only: the display name rides whole as the given name
            // rather than being guessed apart.
            card.givenName = displayName
        }
        guard sawName || displayName != nil else { return nil }
        return .contact(card)
    }

    /// `TYPE=CELL`, `TYPE=cell,voice`, or vCard 2.1's bare `CELL`.
    private static func label(in parameters: [String]) -> Contact.Label? {
        for parameter in parameters {
            let bare = parameter.uppercased().hasPrefix("TYPE=")
                ? String(parameter.dropFirst("TYPE=".count)) : parameter
            for token in bare.split(separator: ",") {
                if let match = Contact.Label(rawValue: token.uppercased()) { return match }
            }
        }
        return nil
    }

    /// `1985-04-12` or `19850412`.
    private static func birthday(_ value: String) -> Contact.Birthday? {
        let digits = value.filter(\.isNumber)
        guard digits.count == 8, let year = Int(digits.prefix(4)),
              let month = Int(digits.dropFirst(4).prefix(2)), let day = Int(digits.suffix(2)),
              (1...12).contains(month), (1...31).contains(day) else { return nil }
        return .init(year: year, month: month, day: day)
    }

    // MARK: - Event

    private static func event(_ string: String) -> ParsedPayload? {
        var title: String?, location: String?, start: Date?, end: Date?, allDay = false
        for line in unfoldedLines(string) {
            let (name, parameters, value) = property(line)
            switch name {
            case "SUMMARY": title = unescaped(value)
            case "LOCATION": location = unescaped(value)
            case "DTSTART":
                if parameters.contains(where: { $0.uppercased() == "VALUE=DATE" }) { allDay = true }
                start = stamp(value)
            case "DTEND": end = stamp(value)
            default: break
            }
        }
        guard let title, let start else { return nil }
        return .event(Event(title: title, location: location, start: start, end: end, allDay: allDay))
    }

    /// `20260901T190000Z`, the same without `Z` (read as UTC — the
    /// floating-time nuance is deliberately dropped), or a bare date.
    /// Formatting the parse back and comparing rejects overflowed
    /// values a lenient calendar would silently roll over.
    static func stamp(_ value: String) -> Date? {
        for format in ["yyyyMMdd'T'HHmmss'Z'", "yyyyMMdd'T'HHmmss", "yyyyMMdd"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = format
            formatter.isLenient = false
            if let date = formatter.date(from: value), formatter.string(from: date) == value {
                return date
            }
        }
        return nil
    }

    // MARK: - URI forms

    private static func mailto(_ string: String) -> ParsedPayload {
        let rest = string.dropFirst("mailto:".count)
        let halves = rest.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        var cc: String?, subject: String?, body: String?
        if halves.count == 2 {
            for pair in halves[1].split(separator: "&") {
                let sides = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                guard sides.count == 2 else { continue }
                let value = String(sides[1]).removingPercentEncoding ?? String(sides[1])
                switch sides[0].lowercased() {
                case "cc": cc = value
                case "subject": subject = value
                case "body": body = value
                default: break   // bcc and unknown keys, dropped
                }
            }
        }
        return .email(to: String(halves[0]), cc: cc, subject: subject, body: body)
    }

    private static func sms(_ string: String) -> ParsedPayload {
        let rest = string.dropFirst("sms:".count)
        let halves = rest.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        var body: String?
        if halves.count == 2 {
            for pair in halves[1].split(separator: "&") {
                let sides = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                if sides.count == 2, sides[0].lowercased() == "body" {
                    body = String(sides[1]).removingPercentEncoding ?? String(sides[1])
                }
            }
        }
        return .sms(number: String(halves[0]), body: body)
    }

    /// The legacy `SMSTO:number:body` form some scanners emit.
    private static func smsto(_ string: String) -> ParsedPayload {
        let rest = string.dropFirst("smsto:".count)
        let halves = rest.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let body = halves.count == 2 && !halves[1].isEmpty ? String(halves[1]) : nil
        return .sms(number: String(halves[0]), body: body)
    }

    private static func geo(_ string: String) -> ParsedPayload? {
        // Altitude and query parts (`geo:lat,lon,alt?z=17`) are dropped.
        let head = string.dropFirst("geo:".count).split(separator: "?", maxSplits: 1).first ?? ""
        let coordinates = head.split(separator: ",")
        guard coordinates.count >= 2,
              let latitude = Double(coordinates[0]), let longitude = Double(coordinates[1]) else { return nil }
        return .geo(latitude: latitude, longitude: longitude)
    }

    // MARK: - WhatsApp

    /// `https://wa.me/66812345678?text=...` surfaced as its meaning. A
    /// wa.me link with no digits falls back to a plain URL.
    private static func whatsapp(_ string: String) -> ParsedPayload {
        let parts = string.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count >= 3 else { return .url(string) }
        let tail = parts[2].split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let number = tail[0].filter { $0.isASCII && $0.isNumber }
        guard !number.isEmpty else { return .url(string) }
        var message: String?
        if tail.count == 2 {
            for pair in tail[1].split(separator: "&") {
                let sides = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                if sides.count == 2, sides[0].lowercased() == "text" {
                    message = String(sides[1]).removingPercentEncoding ?? String(sides[1])
                }
            }
        }
        return .whatsapp(number: number, message: message)
    }

    // MARK: - Shared machinery

    /// Lines with folded continuations joined — a leading space or tab
    /// continues the previous line, and the marker character is removed.
    /// CRLF is ONE Character in Swift, so splitting on `isNewline`
    /// handles both line-end styles at once.
    static func unfoldedLines(_ string: String) -> [String] {
        var lines: [String] = []
        for piece in string.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline) {
            if let first = piece.first, first == " " || first == "\t", !lines.isEmpty {
                lines[lines.count - 1] += piece.dropFirst()
            } else {
                lines.append(String(piece))
            }
        }
        return lines
    }

    /// `NAME;PARAM;PARAM:value` split into its three parts. The value
    /// keeps any further colons — URLs live there.
    static func property(_ line: String) -> (name: String, parameters: [String], value: String) {
        let halves = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let head = halves[0].split(separator: ";", omittingEmptySubsequences: false)
        let name = head.isEmpty ? "" : String(head[0]).uppercased()
        let parameters = head.dropFirst().map(String.init)
        return (name, parameters, halves.count == 2 ? String(halves[1]) : "")
    }

    /// Split on a separator, honouring backslash escapes — the escaped
    /// pair stays in place for ``unescaped(_:)`` to undo.
    static func splitUnescaped(_ value: String, on separator: Character) -> [String] {
        var parts: [String] = [""], escaped = false
        for character in value {
            if escaped { parts[parts.count - 1].append(character); escaped = false; continue }
            if character == "\\" { parts[parts.count - 1].append(character); escaped = true; continue }
            if character == separator { parts.append("") } else { parts[parts.count - 1].append(character) }
        }
        return parts
    }

    /// vCard escaping undone: `\n` to a newline, `\;` `\,` `\\` to the
    /// bare character. An unknown escape keeps its character.
    static func unescaped(_ value: String) -> String {
        var out = "", escaped = false
        for character in value {
            if escaped {
                if character == "n" || character == "N" { out.append("\n") } else { out.append(character) }
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else {
                out.append(character)
            }
        }
        return out
    }
}
