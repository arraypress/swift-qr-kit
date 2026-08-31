//
//  Contact.swift
//  QRKit
//
//  Created by David Sherlock on 2026.
//
//  A contact with the fields real cards carry — the shape only. How one
//  becomes vCard 3.0 lives in Support/PayloadEncoding; how a scanned
//  card becomes one of these lives in Support/PayloadDecoding.
//

/// A contact card with typed, labelled fields.
///
/// The richer sibling of ``QRPayload/vCard(name:phone:email:organization:url:)``:
/// a proper given/family split, any number of labelled phones and emails,
/// a postal address, a title, a birthday and a note.
public struct Contact: Sendable, Equatable {

    /// What a phone or email is for — becomes the vCard `TYPE`.
    public enum Label: String, Sendable, CaseIterable {
        case cell = "CELL"
        case work = "WORK"
        case home = "HOME"
    }

    /// One phone or email, optionally labelled.
    public struct Field: Sendable, Equatable {
        public var label: Label?
        public var value: String

        public init(_ value: String, label: Label? = nil) {
            self.value = value
            self.label = label
        }
    }

    /// A postal address; empty parts are simply absent from the card.
    public struct PostalAddress: Sendable, Equatable {
        public var street: String?
        public var city: String?
        public var region: String?
        public var postalCode: String?
        public var country: String?

        public init(street: String? = nil, city: String? = nil, region: String? = nil,
                    postalCode: String? = nil, country: String? = nil) {
            self.street = street; self.city = city; self.region = region
            self.postalCode = postalCode; self.country = country
        }
    }

    /// A date without a time — birthdays have no timezone.
    public struct Birthday: Sendable, Equatable {
        public var year: Int
        public var month: Int
        public var day: Int

        public init(year: Int, month: Int, day: Int) {
            self.year = year; self.month = month; self.day = day
        }
    }

    /// Given name — the second slot of the vCard `N` field.
    public var givenName: String
    /// Family name — the first slot of the vCard `N` field.
    public var familyName: String
    public var phones: [Field]
    public var emails: [Field]
    public var organization: String?
    public var title: String?
    public var address: PostalAddress?
    public var birthday: Birthday?
    public var urls: [String]
    public var note: String?

    public init(givenName: String, familyName: String = "",
                phones: [Field] = [], emails: [Field] = [],
                organization: String? = nil, title: String? = nil,
                address: PostalAddress? = nil, birthday: Birthday? = nil,
                urls: [String] = [], note: String? = nil) {
        self.givenName = givenName; self.familyName = familyName
        self.phones = phones; self.emails = emails
        self.organization = organization; self.title = title
        self.address = address; self.birthday = birthday
        self.urls = urls; self.note = note
    }
}
