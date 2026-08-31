//
//  PayloadTests.swift
//  QRKitTests
//
//  Created by David Sherlock on 2026.
//
//  The new payloads pinned to the exact string, the decoding mirror
//  pinned by round trips and by tolerance for foreign cards, and the
//  SVG checked as a document against the same matrix.
//

import Foundation
import XCTest
@testable import QRKit

final class PayloadTests: XCTestCase {

    private let reference = ISO8601DateFormatter().date(from: "2026-09-01T19:00:00Z")!

    // MARK: - New encodings, to the exact string

    func testSAEWifiPayload() {
        let payload = QRPayload.wifi(ssid: "Lab", password: "s3cret", security: .sae, hidden: false)
        XCTAssertEqual(payload.encoded, "WIFI:T:SAE;S:Lab;P:s3cret;;")
    }

    func testRichContactIsExactVCard3() {
        let card = Contact(givenName: "Jane", familyName: "van Doe",
                           phones: [.init("+66 1 234", label: .cell), .init("+66 2 000", label: .work)],
                           emails: [.init("jane@example.com")],
                           organization: "Acme, Inc", title: "Director; Ops",
                           address: .init(street: "1 Main St", city: "Bangkok", postalCode: "10110", country: "TH"),
                           birthday: .init(year: 1985, month: 4, day: 12),
                           urls: ["https://jane.example", "https://acme.example"],
                           note: "Met at\nthe fair")
        XCTAssertEqual(QRPayload.contact(card).encoded, [
            "BEGIN:VCARD", "VERSION:3.0",
            "FN:Jane van Doe",
            "N:van Doe;Jane;;;",
            "TEL;TYPE=CELL:+66 1 234",
            "TEL;TYPE=WORK:+66 2 000",
            "EMAIL:jane@example.com",
            #"ORG:Acme\, Inc"#,
            #"TITLE:Director\; Ops"#,
            "ADR:;;1 Main St;Bangkok;;10110;TH",
            "BDAY:1985-04-12",
            "URL:https://jane.example",
            "URL:https://acme.example",
            #"NOTE:Met at\nthe fair"#,
            "END:VCARD",
        ].joined(separator: "\r\n"))
    }

    func testEventPayloadTimedAndAllDay() {
        let timed = QRPayload.event(Event(title: "Fleet demo; live", location: "HQ, room 2",
                                          start: reference, end: reference.addingTimeInterval(3600)))
        XCTAssertEqual(timed.encoded, [
            "BEGIN:VCALENDAR", "VERSION:2.0", "BEGIN:VEVENT",
            #"SUMMARY:Fleet demo\; live"#,
            #"LOCATION:HQ\, room 2"#,
            "DTSTART:20260901T190000Z",
            "DTEND:20260901T200000Z",
            "END:VEVENT", "END:VCALENDAR",
        ].joined(separator: "\r\n"))
        let allDay = QRPayload.event(Event(title: "Launch", start: reference, allDay: true)).encoded
        XCTAssertTrue(allDay.contains("DTSTART;VALUE=DATE:20260901"))
        XCTAssertFalse(allDay.contains("DTEND"))
    }

    func testEmailPayloadOrdersAndEscapesItsQuery() {
        let payload = QRPayload.email(to: "a@b.c", cc: "boss@b.c", subject: "hi there", body: "line one")
        XCTAssertEqual(payload.encoded, "mailto:a@b.c?cc=boss@b.c&subject=hi%20there&body=line%20one")
        XCTAssertEqual(QRPayload.email(to: "a@b.c", cc: nil, subject: nil, body: nil).encoded, "mailto:a@b.c")
    }

    // MARK: - The decoding mirror

    func testRoundTripsThroughTheDecodingMirror() {
        let password = #"a,b:c"d\e"#
        let wifi = QRPayload.wifi(ssid: "my;net", password: password, security: .wpa, hidden: true)
        XCTAssertEqual(ParsedPayload(parsing: wifi.encoded),
                       .wifi(ssid: "my;net", password: password, security: .wpa, hidden: true))

        let card = Contact(givenName: "Jane", familyName: "Doe",
                           phones: [.init("+66 1", label: .cell)], emails: [.init("j@e.com", label: .work)],
                           organization: "Acme, Inc", title: "Dir",
                           address: .init(street: "1 Main; St", city: "BKK"),
                           birthday: .init(year: 1985, month: 4, day: 12),
                           urls: ["https://j.example"], note: "hi\nthere")
        XCTAssertEqual(ParsedPayload(parsing: QRPayload.contact(card).encoded), .contact(card))

        let timed = Event(title: "Demo; live", location: "HQ, 2", start: reference,
                          end: reference.addingTimeInterval(1800))
        XCTAssertEqual(ParsedPayload(parsing: QRPayload.event(timed).encoded), .event(timed))
        // An all-day event's time of day is deliberately dropped, so the
        // round trip holds for the date itself.
        let midnight = ISO8601DateFormatter().date(from: "2026-09-01T00:00:00Z")!
        let allDay = Event(title: "Launch", start: midnight, allDay: true)
        XCTAssertEqual(ParsedPayload(parsing: QRPayload.event(allDay).encoded), .event(allDay))

        let email = QRPayload.email(to: "a@b.c", cc: "c@b.c", subject: "Q3 & Q4", body: "x=y")
        XCTAssertEqual(ParsedPayload(parsing: email.encoded),
                       .email(to: "a@b.c", cc: "c@b.c", subject: "Q3 & Q4", body: "x=y"))

        XCTAssertEqual(ParsedPayload(parsing: QRPayload.tel("+123").encoded), .tel("+123"))
        XCTAssertEqual(ParsedPayload(parsing: QRPayload.sms("+123", body: "on my way").encoded),
                       .sms(number: "+123", body: "on my way"))
        XCTAssertEqual(ParsedPayload(parsing: "SMSTO:+123:see you"), .sms(number: "+123", body: "see you"))
        XCTAssertEqual(ParsedPayload(parsing: QRPayload.geo(latitude: 13.75, longitude: 100.5).encoded),
                       .geo(latitude: 13.75, longitude: 100.5))
        XCTAssertEqual(ParsedPayload(parsing: "https://example.com/x"), .url("https://example.com/x"))
        XCTAssertEqual(ParsedPayload(parsing: "just words"), .text("just words"))
    }

    func testOldStyleAndForeignVCardsParse() {
        // The library's own simple vCard: the whole display name rides in
        // N's first slot — the parse reports exactly that, no guessing.
        let simple = QRPayload.vCard(name: "Jane Doe", phone: "+66 1", email: nil,
                                     organization: nil, url: nil).encoded
        guard case .contact(let parsed) = ParsedPayload(parsing: simple) else { return XCTFail("not a contact") }
        XCTAssertEqual(parsed.familyName, "Jane Doe")
        XCTAssertEqual(parsed.phones, [.init("+66 1")])

        // A 2.1-style card: LF line ends, bare TYPE parameter, a folded
        // NOTE continuation. The fold marker is removed, per the RFC.
        let foreign = "BEGIN:VCARD\nVERSION:2.1\nN:Doe;Jane\nTEL;CELL:+1 555\nNOTE:one\n two\nEND:VCARD"
        guard case .contact(let old) = ParsedPayload(parsing: foreign) else { return XCTFail("not a contact") }
        XCTAssertEqual(old.givenName, "Jane")
        XCTAssertEqual(old.familyName, "Doe")
        XCTAssertEqual(old.phones, [.init("+1 555", label: .cell)])
        XCTAssertEqual(old.note, "onetwo")

        // FN-only: the display name rides whole as the given name.
        let bare = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Ada Lovelace\r\nEND:VCARD"
        guard case .contact(let fnOnly) = ParsedPayload(parsing: bare) else { return XCTFail("not a contact") }
        XCTAssertEqual(fnOnly.givenName, "Ada Lovelace")
    }

    func testDecodingPrimitivesAlone() {
        XCTAssertEqual(PayloadDecoding.unescaped(#"a\;b\,c\\d\ne"#), "a;b,c\\d\ne")
        XCTAssertEqual(PayloadDecoding.splitUnescaped(#"x\;y;z"#, on: ";"), [#"x\;y"#, "z"])
        XCTAssertEqual(PayloadDecoding.property("TEL;TYPE=CELL:+66 1").name, "TEL")
        XCTAssertEqual(PayloadDecoding.property("TEL;TYPE=CELL:+66 1").parameters, ["TYPE=CELL"])
        XCTAssertEqual(PayloadDecoding.property("URL:https://x.example/a:b").value, "https://x.example/a:b")
        XCTAssertEqual(PayloadDecoding.unfoldedLines("A:1\r\nB:2\n  tail"), ["A:1", "B:2 tail"])
        XCTAssertNil(PayloadDecoding.stamp("20261340T000000Z"), "month 13 is refused, not rolled over")
        XCTAssertEqual(PayloadDecoding.stamp("20260901"),
                       ISO8601DateFormatter().date(from: "2026-09-01T00:00:00Z"))
        XCTAssertEqual(PayloadEncoding.utcStamp(reference), "20260901T190000Z")
        XCTAssertEqual(PayloadEncoding.percentQuery("a&b=c d"), "a%26b%3Dc%20d",
                       "query separators are escaped or a subject splits itself")
    }

    // MARK: - SVG

    func testSVGIsAWellFormedMirrorOfTheMatrix() throws {
        let payload = QRPayload.text("svg check")
        let svg = try QRGenerator.svg(for: payload, size: 512,
                                      foreground: QRColor(red: 1, green: 0, blue: 0),
                                      background: .white)
        let document = try XMLDocument(xmlString: svg)
        XCTAssertEqual(document.rootElement()?.name, "svg")
        let matrix = try QRGenerator.matrix(for: payload)
        let total = matrix.count + 8
        XCTAssertEqual(document.rootElement()?.attribute(forName: "viewBox")?.stringValue,
                       "0 0 \(total) \(total)")
        XCTAssertEqual(document.rootElement()?.attribute(forName: "width")?.stringValue,
                       "\((512 / total) * total)", "pixel size follows the bitmap's whole-pixel rule")
        // Every horizontal run of dark modules is exactly one M command.
        var runs = 0
        for row in matrix {
            var previous = false
            for module in row { if module && !previous { runs += 1 }; previous = module }
        }
        XCTAssertEqual(svg.components(separatedBy: "M").count - 1, runs)
        XCTAssertTrue(svg.contains(##"fill="#FF0000""##))
    }

    // MARK: - Vision

    func testSAEWifiRoundTripsThroughVision() throws {
        let payload = QRPayload.wifi(ssid: "Lab;Net", password: "s3;cret", security: .sae, hidden: true)
        let started = Date()
        let image = try QRGenerator.image(for: payload, size: 512)
        let codes = try QRReader.codes(in: image)
        let took = Date().timeIntervalSince(started)
        XCTAssertEqual(codes.count, 1)
        XCTAssertEqual(codes.first?.parsed,
                       .wifi(ssid: "Lab;Net", password: "s3;cret", security: .sae, hidden: true))
        print("SAE wifi generate+read+parse: \(Int(took * 1000)) ms")
    }

    // MARK: - WhatsApp

    func testWhatsAppPayloadAndItsNormalizer() {
        let chat = QRPayload.whatsapp(number: "+66 (81) 234-5678", message: "on my way")
        XCTAssertEqual(chat.encoded, "https://wa.me/66812345678?text=on%20my%20way")
        XCTAssertEqual(QRPayload.whatsapp(number: "66812345678", message: nil).encoded,
                       "https://wa.me/66812345678")
        // The normalizer alone, no model constructed.
        XCTAssertEqual(PayloadEncoding.whatsappNumber("+66 (81) 234-5678"), "66812345678")
        XCTAssertNil(PayloadEncoding.whatsappNumber("call me"))
        // The mirror: a wa.me link is its meaning, not a bare URL.
        XCTAssertEqual(ParsedPayload(parsing: chat.encoded),
                       .whatsapp(number: "66812345678", message: "on my way"))
        XCTAssertEqual(ParsedPayload(parsing: "https://wa.me/qr/ABC123"),
                       .url("https://wa.me/qr/ABC123"), "a digitless wa.me link stays a URL")
    }
}
