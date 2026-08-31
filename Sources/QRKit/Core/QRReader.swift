//
//  QRReader.swift
//  QRKit
//
//  Created by David Sherlock on 2026.
//
//  Codes out of pixels, via Vision — QR and every other barcode family
//  the system decodes, entirely on device.
//

import CoreGraphics
import Foundation
import ImageIO
import Vision

/// Reads barcodes from images.
public enum QRReader {

    /// Every code in the image, in Vision's confidence order. Empty when
    /// the image holds none — absence is an answer, not an error.
    public static func codes(in image: CGImage) throws -> [ScannedCode] {
        let request = VNDetectBarcodesRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let payload = observation.payloadStringValue else { return nil }
            let box = observation.boundingBox   // normalised, bottom-left origin
            let bounds = CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
            let symbology = observation.symbology.rawValue.replacingOccurrences(of: "VNBarcodeSymbology", with: "")
            return ScannedCode(payload: payload, symbology: symbology, bounds: bounds)
        }
    }

    /// Every code in the file at `url`.
    public static func codes(at url: URL) throws -> [ScannedCode] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw QRError.unreadableImage(url.path)
        }
        return try codes(in: image)
    }
}
