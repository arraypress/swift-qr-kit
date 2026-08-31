//
//  Event.swift
//  QRKit
//
//  Created by David Sherlock on 2026.
//
//  A calendar event — the shape only. The iCalendar wrapper it becomes
//  lives in Support/PayloadEncoding; reading one back lives in
//  Support/PayloadDecoding.
//

import Foundation

/// A calendar event a phone camera offers to add.
public struct Event: Sendable, Equatable {
    public var title: String
    public var location: String?
    /// When it starts. For an all-day event only the date matters.
    public var start: Date
    public var end: Date?
    /// A date-only event; times are dropped from the encoding.
    public var allDay: Bool

    public init(title: String, location: String? = nil,
                start: Date, end: Date? = nil, allDay: Bool = false) {
        self.title = title; self.location = location
        self.start = start; self.end = end; self.allDay = allDay
    }
}
