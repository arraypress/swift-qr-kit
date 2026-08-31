//
//  ParsedPayload+Parsing.swift
//  QRKit
//
//  Created by David Sherlock on 2026.
//
//  The model's way in for strings that arrived without a ScannedCode —
//  pasted, piped, or read some other way. Pure delegation.
//

extension ParsedPayload {

    /// Decode any payload string into its meaning.
    public init(parsing raw: String) {
        self = PayloadDecoding.parse(raw)
    }
}
