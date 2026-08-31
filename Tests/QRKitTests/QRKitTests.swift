//
//  QRKitTests.swift
//  QRKitTests
//
//  Created by David Sherlock on 2026.
//
//  Payload strings to the character, matrices with real finder patterns,
//  and a generate → Vision-read round trip that never leaves the machine.
//

import CoreGraphics
import Foundation
import XCTest
@testable import QRKit

final class QRKitTests: XCTestCase {

    func testWifiPayloadEscapesTheCharactersThatTruncateCredentials() {
        let plain = QRPayload.wifi(ssid: "HomeNet", password: "hunter2", security: .wpa, hidden: false)
        XCTAssertEqual(plain.encoded, "WIFI:T:WPA;S:HomeNet;P:hunter2;;")
        let tricky = QRPayload.wifi(ssid: "my;net", password: "a,b:c\"d\\e", security: .wpa, hidden: true)
        XCTAssertEqual(tricky.encoded, #"WIFI:T:WPA;S:my\;net;P:a\,b\:c\"d\\e;H:true;;"#)
        let open = QRPayload.wifi(ssid: "Cafe", password: "ignored", security: .open, hidden: false)
        XCTAssertEqual(open.encoded, "WIFI:T:nopass;S:Cafe;;", "an open network carries no password")
    }

    func testVCardPayloadIsExactCRLFSeparatedVCard3() {
        let card = QRPayload.vCard(name: "Doe; Jane", phone: "+66 1 234", email: "jane@example.com",
                                   organization: "Acme, Inc", url: nil)
        XCTAssertEqual(card.encoded, [
            "BEGIN:VCARD", "VERSION:3.0",
            #"FN:Doe\; Jane"#, #"N:Doe\; Jane;;;;"#,
            "TEL:+66 1 234", "EMAIL:jane@example.com", #"ORG:Acme\, Inc"#,
            "END:VCARD",
        ].joined(separator: "\r\n"))
    }

    func testSmallPayloadForms() {
        XCTAssertEqual(QRPayload.tel("+123").encoded, "tel:+123")
        XCTAssertEqual(QRPayload.geo(latitude: 13.75, longitude: 100.5).encoded, "geo:13.75,100.5")
        XCTAssertEqual(QRPayload.mailto("a@b.c", subject: "hi there").encoded, "mailto:a@b.c?subject=hi%20there")
        XCTAssertEqual(QRPayload.sms("+123", body: nil).encoded, "sms:+123")
    }

    func testMatrixIsVersionSizedWithFinderPatterns() throws {
        let matrix = try QRGenerator.matrix(for: .text("hello"))
        XCTAssertGreaterThanOrEqual(matrix.count, 21)
        XCTAssertTrue(matrix.allSatisfy { $0.count == matrix.count }, "square")
        // Finder pattern corners are dark in every QR code.
        XCTAssertTrue(matrix[0][0] && matrix[0][matrix.count - 1] && matrix[matrix.count - 1][0])
        // Immediately inside the finder ring is light.
        XCTAssertFalse(matrix[1][1])
    }

    func testGenerateReadRoundTripThroughVision() throws {
        let payload = QRPayload.text("https://example.com/héllo ✓ 42")
        let started = Date()
        let image = try QRGenerator.image(for: payload, size: 512)
        let codes = try QRReader.codes(in: image)
        let took = Date().timeIntervalSince(started)
        XCTAssertEqual(codes.count, 1)
        XCTAssertEqual(codes.first?.payload, payload.encoded)
        XCTAssertEqual(codes.first?.symbology, "QR")
        let bounds = try XCTUnwrap(codes.first?.bounds)
        XCTAssertTrue(bounds.width > 0.5 && bounds.width <= 1, "the code fills most of its own image")
        print("round trip generate+read: \(Int(took * 1000)) ms")
    }

    func testColoursAndSizeAreHonoured() throws {
        let image = try QRGenerator.image(for: .text("x"), size: 300,
                                          foreground: QRColor(red: 1, green: 0, blue: 0),
                                          background: QRColor(red: 0, green: 0, blue: 1))
        // Whole-pixel modules: the side is the largest module multiple ≤ requested.
        XCTAssertLessThanOrEqual(image.width, 300)
        XCTAssertGreaterThan(image.width, 200)
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = CGContext(data: &pixels, width: image.width, height: image.height,
                                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        XCTAssertGreaterThan(pixels[2], 200, "the corner quiet zone wears the background blue")
        var sawRed = false
        for i in stride(from: 0, to: pixels.count, by: 4) where pixels[i] > 200 && pixels[i + 2] < 80 { sawRed = true; break }
        XCTAssertTrue(sawRed, "dark modules wear the foreground red")
    }

    func testWritePNGRoundTripsFromDisk() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("qr-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }
        try QRGenerator.writePNG(.wifi(ssid: "TestNet", password: "s3cret", security: .wpa, hidden: false), to: url)
        let codes = try QRReader.codes(at: url)
        XCTAssertEqual(codes.first?.payload, "WIFI:T:WPA;S:TestNet;P:s3cret;;")
    }

    func testMatrixRendererOnAHandMadeGrid() throws {
        let grid = [[true, false], [false, true]]
        let image = try MatrixRenderer.image(from: grid, size: 60, quietZone: 1,
                                             foreground: .black, background: .white)
        XCTAssertEqual(image.width, 60, "2 modules + 2 quiet on each side = 4 · 15 px")
    }

    func testEscapingPrimitivesAlone() {
        // The rules pinned with no payload in sight — the point of the
        // Support split: an escaping rule is testable by itself.
        XCTAssertEqual(PayloadEncoding.wifiEscaped(#"a\b;c,d:e"f"#), #"a\\b\;c\,d\:e\"f"#)
        XCTAssertEqual(PayloadEncoding.vCardEscaped("Line\r\nBreak; and, slash\\"), #"Line\nBreak\; and\, slash\\"#)
        XCTAssertEqual(PayloadEncoding.percentQuery("hi there"), "hi%20there")
        XCTAssertNil(PayloadEncoding.percentQuery(nil))
    }
}
