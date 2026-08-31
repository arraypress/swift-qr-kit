//
//  QRPayload+Encoded.swift
//  QRKit
//
//  Created by David Sherlock on 2026.
//
//  The model's one derived fact: the exact string a code carries. Every
//  case is a single delegation into PayloadEncoding — no rule lives here,
//  so no rule can hide here.
//

import Foundation

extension QRPayload {

    /// The exact string the code carries.
    public var encoded: String {
        switch self {
        case .text(let value):
            return value
        case .wifi(let ssid, let password, let security, let hidden):
            return PayloadEncoding.wifi(ssid: ssid, password: password, security: security, hidden: hidden)
        case .vCard(let name, let phone, let email, let organization, let url):
            return PayloadEncoding.vCard(name: name, phone: phone, email: email, organization: organization, url: url)
        case .mailto(let address, let subject):
            return PayloadEncoding.mailto(address, subject: subject)
        case .tel(let number):
            return "tel:\(number)"
        case .sms(let number, let body):
            return PayloadEncoding.sms(number, body: body)
        case .geo(let latitude, let longitude):
            return "geo:\(latitude),\(longitude)"
        case .contact(let card):
            return PayloadEncoding.contact(card)
        case .event(let event):
            return PayloadEncoding.event(title: event.title, location: event.location,
                                         start: event.start, end: event.end, allDay: event.allDay)
        case .email(let to, let cc, let subject, let body):
            return PayloadEncoding.email(to: to, cc: cc, subject: subject, body: body)
        case .whatsapp(let number, let message):
            return PayloadEncoding.whatsapp(number: number, message: message)
        }
    }
}
