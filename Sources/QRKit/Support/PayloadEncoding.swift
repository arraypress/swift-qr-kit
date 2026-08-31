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

    /// A query value percent-encoded, or nothing for nothing. `&`, `=`,
    /// `+` and `?` are escaped too — legal in a query, but they SPLIT
    /// one: an ampersand in a subject would silently become a second
    /// parameter on the phone that scans it.
    static func percentQuery(_ value: String?) -> String? {
        value.flatMap { $0.addingPercentEncoding(withAllowedCharacters: queryValue) }
    }

    private static let queryValue: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "&=+?")
        return set
    }()

    // MARK: - Rich contact

    /// The full-field vCard 3.0 — CRLF line ends, labels as `TYPE`
    /// parameters, optional fields dropped not blanked.
    static func contact(_ card: Contact) -> String {
        let display = [card.givenName, card.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        var lines = ["BEGIN:VCARD", "VERSION:3.0",
                     "FN:\(vCardEscaped(display))",
                     "N:\(vCardEscaped(card.familyName));\(vCardEscaped(card.givenName));;;"]
        for phone in card.phones { lines.append("TEL\(typeParameter(phone.label)):\(vCardEscaped(phone.value))") }
        for email in card.emails { lines.append("EMAIL\(typeParameter(email.label)):\(vCardEscaped(email.value))") }
        if let organization = card.organization { lines.append("ORG:\(vCardEscaped(organization))") }
        if let title = card.title { lines.append("TITLE:\(vCardEscaped(title))") }
        if let address = card.address {
            let parts = ["", "", address.street ?? "", address.city ?? "", address.region ?? "",
                         address.postalCode ?? "", address.country ?? ""]
            lines.append("ADR:" + parts.map(vCardEscaped).joined(separator: ";"))
        }
        if let birthday = card.birthday {
            lines.append("BDAY:" + String(format: "%04d-%02d-%02d", birthday.year, birthday.month, birthday.day))
        }
        for url in card.urls { lines.append("URL:\(vCardEscaped(url))") }
        if let note = card.note { lines.append("NOTE:\(vCardEscaped(note))") }
        lines.append("END:VCARD")
        return lines.joined(separator: "\r\n")
    }

    /// `;TYPE=CELL`, or nothing for an unlabelled field.
    private static func typeParameter(_ label: Contact.Label?) -> String {
        label.map { ";TYPE=\($0.rawValue)" } ?? ""
    }

    // MARK: - Event

    /// A VEVENT in its VCALENDAR envelope — cameras want the wrapper.
    /// iCalendar text escaping is the vCard family's, so the primitive
    /// is shared.
    static func event(title: String, location: String?, start: Date, end: Date?, allDay: Bool) -> String {
        var lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "BEGIN:VEVENT",
                     "SUMMARY:\(vCardEscaped(title))"]
        if let location { lines.append("LOCATION:\(vCardEscaped(location))") }
        if allDay {
            lines.append("DTSTART;VALUE=DATE:\(dateStamp(start))")
            if let end { lines.append("DTEND;VALUE=DATE:\(dateStamp(end))") }
        } else {
            lines.append("DTSTART:\(utcStamp(start))")
            if let end { lines.append("DTEND:\(utcStamp(end))") }
        }
        lines += ["END:VEVENT", "END:VCALENDAR"]
        return lines.joined(separator: "\r\n")
    }

    /// An email compose action with cc and body, values percent-encoded.
    static func email(to: String, cc: String?, subject: String?, body: String?) -> String {
        var pairs: [String] = []
        if let value = percentQuery(cc) { pairs.append("cc=\(value)") }
        if let value = percentQuery(subject) { pairs.append("subject=\(value)") }
        if let value = percentQuery(body) { pairs.append("body=\(value)") }
        return "mailto:\(to)" + (pairs.isEmpty ? "" : "?" + pairs.joined(separator: "&"))
    }

    // MARK: - WhatsApp

    /// A `wa.me` chat link — WhatsApp's own scheme is app-internal; the
    /// link form is what cameras open.
    static func whatsapp(number: String, message: String?) -> String {
        "https://wa.me/\(whatsappNumber(number) ?? "")"
            + (percentQuery(message).map { "?text=\($0)" } ?? "")
    }

    /// Bare international digits: `+66 (81) 234-5678` becomes
    /// `66812345678` — or nothing at all when no digits survive, which
    /// callers must refuse before encoding.
    static func whatsappNumber(_ raw: String) -> String? {
        let digits = raw.filter { $0.isASCII && $0.isNumber }
        return digits.isEmpty ? nil : digits
    }

    // MARK: - Timestamps

    /// `20260901T190000Z` — the iCalendar basic format, UTC. Built per
    /// call; formatters are not Sendable, per the fleet convention.
    static func utcStamp(_ date: Date) -> String {
        stampFormatter("yyyyMMdd'T'HHmmss'Z'").string(from: date)
    }

    /// `20260901` — a date with no time, UTC.
    static func dateStamp(_ date: Date) -> String {
        stampFormatter("yyyyMMdd").string(from: date)
    }

    private static func stampFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = format
        return formatter
    }
}
