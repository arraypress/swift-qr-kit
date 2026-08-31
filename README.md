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

A semicolon in a Wi-Fi password is the classic silently-broken QR code: the format treats `;` as a field separator, so an unescaped one truncates the credentials and the code *scans fine* — it just joins nothing. The builders — `text`, `wifi`, `vCard`, `mailto`, `tel`, `sms`, `geo` — carry the escaping rules once, tested to the exact output string.

## Why rendering is whole-pixel

`QRGenerator.matrix(for:)` gives the code as a `[[Bool]]` of modules (Core Image's one-module light border trimmed off). The bitmap is drawn from that matrix — every module an exact block of pixels, a four-module quiet zone, any colours — because scaling the generator's one-pixel-per-module output through a sampler blurs exactly the edges that make a code scannable. The matrix is also how a terminal rendering or a custom style gets built.

## Reading

`QRReader` wraps Vision's barcode detector: every code in the image, with its payload, family (QR, EAN-13, Code 128, …) and position as fractions of the image, top-left origin. Absence is an empty array, not an error.

## Measured

A 512 px generate → write → Vision read round trip is **~130 ms** first call (Vision's model load included) and falls well under that warm. All local; nothing leaves the machine.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/arraypress/swift-qr-kit.git", from: "0.1.0")
]
```

## Requirements

- macOS 13+ / iOS 16+
- Swift 6

## License

MIT — see [LICENSE](LICENSE).
