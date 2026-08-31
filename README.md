# swift-qr-kit

QR codes in both directions, entirely on device — Core Image makes them, Vision reads them, and the payloads people actually put in codes are typed values that escape themselves correctly.

```swift
import QRKit

// A Wi-Fi code a phone camera joins directly.
let payload = QRPayload.wifi(ssid: "HomeNet", password: "hunter;2", security: .wpa, hidden: false)
try QRGenerator.writePNG(payload, to: url, size: 1024, level: .high)

// Everything a photo's barcodes say.
let codes = try QRReader.codes(at: photoURL)   // payload, symbology, position
```

## Why payloads are typed

A semicolon in a Wi-Fi password is the classic silently-broken QR code: the format treats `;` as a field separator, so an unescaped one truncates the credentials and the code *scans fine* — it just joins nothing. The builders — `text`, `wifi` (WPA/WEP/SAE/open), `vCard`, `contact` (labelled phones and emails, address, title, birthday), `event` (a VEVENT cameras add to the calendar), `mailto`, `email` (cc and body), `tel`, `sms`, `whatsapp` (a `wa.me` chat link), `geo` — carry the escaping rules once, tested to the exact output string. Query values escape `&`, `=`, `+` and `?` as well: they are legal in a query but they *split* one, so an ampersand in a subject would silently become a second parameter.

## Why rendering is whole-pixel

`QRGenerator.matrix(for:)` gives the code as a `[[Bool]]` of modules (Core Image's one-module light border trimmed off). The bitmap is drawn from that matrix — every module an exact block of pixels, a four-module quiet zone, any colours — because scaling the generator's one-pixel-per-module output through a sampler blurs exactly the edges that make a code scannable. The matrix is also how a terminal rendering or a custom style gets built.

`QRGenerator.svg(for:)` renders the same matrix as a resolution-free SVG — same quiet zone, same whole-pixel size rule, dark modules merged into horizontal path runs — for print.

## Reading

`QRReader` wraps Vision's barcode detector: every code in the image, with its payload, family (QR, EAN-13, Code 128, …) and position as fractions of the image, top-left origin. Absence is an empty array, not an error.

Every `ScannedCode` also carries `parsed` — the payload decoded into a `ParsedPayload`: Wi-Fi fields with the escaping undone, contacts (vCard 2.1-ish through 3.0, LF or CRLF line ends, folded lines, bare 2.1 `TYPE`s), events, mailto/tel/sms/geo/wa.me forms. Anything unrecognised is `.text`, never an error; `ParsedPayload(parsing:)` does the same for strings from anywhere else. Reading is deliberately lossier than writing — unknown vCard properties, enterprise Wi-Fi fields and an all-day event's time of day are dropped.

## Measured

A 512 px generate → write → Vision read round trip is **~130 ms** first call (Vision's model load included) and falls to **~18 ms** warm; adding `parsed` costs nothing measurable. All escaping and parsing is pinned by encode → parse round-trip tests. All local; nothing leaves the machine.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/arraypress/swift-qr-kit.git", from: "1.1.0")
]
```

## Requirements

- macOS 13+ / iOS 16+
- Swift 6

## License

MIT — see [LICENSE](LICENSE).
