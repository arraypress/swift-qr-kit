//
//  ScannedCode+Parsed.swift
//  QRKit
//
//  Created by David Sherlock on 2026.
//
//  The scanned string's one derived fact — what it means. Pure
//  delegation into PayloadDecoding; no rule lives here.
//

extension ScannedCode {

    /// The payload decoded into its meaning.
    public var parsed: ParsedPayload { PayloadDecoding.parse(payload) }
}
