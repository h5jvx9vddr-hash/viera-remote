import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Infos aus der Gerätebeschreibung (/nrc/ddd.xml).
struct TVInfo: Codable, Equatable {
    var name: String
    var model: String
    var mac: String?
}

enum VieraError: LocalizedError, Equatable {
    case invalidHost
    case notPaired
    case unreachable(String)
    case remoteDisabled
    case rejected(Int, String?)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .invalidHost:
            "Das ist keine gültige IP-Adresse (Beispiel: 192.168.178.40)."
        case .notPaired:
            "Noch kein Fernseher gekoppelt – bitte zuerst die App öffnen."
        case .unreachable(let why):
            "Fernseher nicht erreichbar (\(why)). Ist er eingeschaltet und im selben Netz wie das iPhone?"
        case .remoteDisabled:
            "Der Fernseher lehnt die Steuerung ab. Am TV unter Menü → Netzwerk → Netzwerk-Link-Einstellungen „TV Remote“ einschalten."
        case .rejected(let code, let text):
            "Der Fernseher hat den Befehl abgelehnt (\(text ?? "Fehler \(code)")). Falls gar keine Taste geht: „TV Remote“ am TV einschalten."
        case .badResponse:
            "Unerwartete Antwort – ist unter dieser IP wirklich ein Panasonic VIERA?"
        }
    }
}

/// Spricht das UPnP/SOAP-Protokoll der VIERA-Fernseher (Port 55000). Modelle bis 2018 brauchen keine PIN.
struct VieraClient {
    let host: String
    var port = 55000

    private static let nrcPath = "/nrc/control_0"
    private static let nrcURN = "urn:panasonic-com:service:p00NetworkControl:1"
    private static let dmrPath = "/dmr/control_0"
    private static let renderingURN = "urn:schemas-upnp-org:service:RenderingControl:1"
    private static let channel = "<InstanceID>0</InstanceID><Channel>Master</Channel>"

    static let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 3
        c.timeoutIntervalForResource = 5
        return URLSession(configuration: c)
    }()

    // MARK: Befehle

    func info() async throws -> TVInfo {
        guard let url = URL(string: "http://\(host):\(port)/nrc/ddd.xml") else { throw VieraError.invalidHost }
        let (data, status) = try await load(URLRequest(url: url))
        guard status == 200 else { throw VieraError.rejected(status, nil) }
        let v = XMLValues.parse(data)
        guard !v.isEmpty else { throw VieraError.badResponse }
        return TVInfo(name: v["friendlyName"] ?? "Panasonic VIERA",
                      model: v["modelNumber"] ?? v["modelName"] ?? "VIERA",
                      mac: Self.mac(fromUDN: v["UDN"]))
    }

    func send(_ code: String) async throws {
        _ = try await soap(Self.nrcPath, urn: Self.nrcURN, action: "X_SendKey", args: "<X_KeyEvent>\(code)</X_KeyEvent>")
    }

    func volume() async throws -> Int {
        let v = try await soap(Self.dmrPath, urn: Self.renderingURN, action: "GetVolume", args: Self.channel)
        guard let s = v["CurrentVolume"], let n = Int(s) else { throw VieraError.badResponse }
        return n
    }

    func setVolume(_ n: Int) async throws {
        _ = try await soap(Self.dmrPath, urn: Self.renderingURN, action: "SetVolume",
                           args: Self.channel + "<DesiredVolume>\(max(0, min(100, n)))</DesiredVolume>")
    }

    func muted() async throws -> Bool {
        let v = try await soap(Self.dmrPath, urn: Self.renderingURN, action: "GetMute", args: Self.channel)
        return v["CurrentMute"] == "1"
    }

    func setMute(_ on: Bool) async throws {
        _ = try await soap(Self.dmrPath, urn: Self.renderingURN, action: "SetMute",
                           args: Self.channel + "<DesiredMute>\(on ? 1 : 0)</DesiredMute>")
    }

    // MARK: Hilfen

    /// "192,168,178,40" (deutsche Zifferntastatur) → "192.168.178.40"; nil, wenn keine IPv4.
    static func normalize(_ raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4, parts.allSatisfy({ p in
            Int(p).map { (0...255).contains($0) && String($0) == String(p) } ?? false
        }) else { return nil }
        return s
    }

    /// Beliebige Schreibweise → "AA:BB:CC:DD:EE:FF"; nil, wenn keine gültige MAC.
    static func formatMAC(_ raw: String) -> String? {
        let hex = Array(raw.uppercased().filter(\.isHexDigit))
        guard hex.count == 12, hex.contains(where: { $0 != "0" }) else { return nil }
        return stride(from: 0, to: 12, by: 2).map { String(hex[$0..<$0 + 2]) }.joined(separator: ":")
    }

    /// Panasonic hängt die MAC an die UDN an: uuid:4D454930-0200-1000-8001-A81374D9A1B2
    static func mac(fromUDN udn: String?) -> String? {
        guard let last = udn?.trimmingCharacters(in: .whitespaces).split(separator: "-").last,
              last.count == 12 else { return nil }
        return formatMAC(String(last))
    }

    private func soap(_ path: String, urn: String, action: String, args: String) async throws -> [String: String] {
        guard let url = URL(string: "http://\(host):\(port)\(path)") else { throw VieraError.invalidHost }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        req.setValue("\"\(urn)#\(action)\"", forHTTPHeaderField: "SOAPACTION")
        req.httpBody = Data("""
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:\(action) xmlns:u="\(urn)">\(args)</u:\(action)></s:Body></s:Envelope>
        """.utf8)
        let (data, status) = try await load(req)
        let values = XMLValues.parse(data)
        guard status == 200 else {
            if status == 403 { throw VieraError.remoteDisabled }
            throw VieraError.rejected(status, values["errorDescription"])
        }
        return values
    }

    private func load(_ req: URLRequest) async throws -> (Data, Int) {
        do {
            let (data, resp) = try await Self.session.data(for: req)
            return (data, (resp as? HTTPURLResponse)?.statusCode ?? 0)
        } catch let e as URLError {
            throw VieraError.unreachable(Self.describe(e))
        }
    }

    private static func describe(_ e: URLError) -> String {
        switch e.code {
        case .timedOut: "keine Antwort"
        case .cannotConnectToHost: "Verbindung abgelehnt"
        case .notConnectedToInternet: "kein Netz – „Lokales Netzwerk“ für die App erlaubt?"
        case .networkConnectionLost: "Verbindung abgebrochen"
        default: e.localizedDescription
        }
    }
}

/// Sammelt den ersten Textinhalt je Elementname (Namensraum-Präfix wird ignoriert).
final class XMLValues: NSObject, XMLParserDelegate {
    private var values: [String: String] = [:]
    private var text = ""

    static func parse(_ data: Data) -> [String: String] {
        let d = XMLValues()
        let p = XMLParser(data: data)
        p.delegate = d
        p.parse()
        return d.values
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        text = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.split(separator: ":").last.map(String.init) ?? elementName
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty, values[name] == nil { values[name] = t }
        text = ""
    }
}

/// Magic Packet: 6 × 0xFF + 16 × MAC (getrennt von WakeOnLAN, damit es auch unter Linux testbar ist).
enum WakeOnLANPacket {
    static func bytes(mac: String) -> Data? {
        guard let formatted = VieraClient.formatMAC(mac) else { return nil }
        let macBytes = formatted.split(separator: ":").compactMap { UInt8($0, radix: 16) }
        var bytes = [UInt8](repeating: 0xFF, count: 6)
        for _ in 0..<16 { bytes += macBytes }
        return Data(bytes)
    }
}
