import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

let port = Int(CommandLine.arguments[1])!
var failures = 0

func check(_ ok: Bool, _ what: String) {
    print((ok ? "OK    " : "FEHLER ") + what)
    if !ok { failures += 1 }
}

// Eingabe-Normalisierung
check(VieraClient.normalize(" 192,168,178,40 ") == "192.168.178.40", "IP mit Komma (deutsche Tastatur)")
check(VieraClient.normalize("300.1.1.1") == nil, "ungültige IP abgelehnt")
check(VieraClient.normalize("192.168.1") == nil, "unvollständige IP abgelehnt")
check(VieraClient.formatMAC("a8-13-74-ab-cd-ef") == "A8:13:74:AB:CD:EF", "MAC-Format")
check(VieraClient.formatMAC("00:00:00:00:00:00") == nil, "Null-MAC abgelehnt")
check(WakeOnLANPacket.bytes(mac: "A8:13:74:AB:CD:EF")?.count == 102, "Magic Packet 102 Byte")

let tv = VieraClient(host: "127.0.0.1", port: port)

// Koppeln = Gerätebeschreibung
let info = try await tv.info()
check(info.name == "VIERA_WT50", "Name aus ddd.xml: \(info.name)")
check(info.model == "TX-L55WT50E", "Modell: \(info.model)")
check(info.mac == "A8:13:74:AB:CD:EF", "MAC aus UDN: \(info.mac ?? "-")")

// Tasten
for key in [VieraKey.power, .volumeUp, .enter, .digit(7), .red, .threeD] {
    try await tv.send(key.rawValue)
}
let log = try String(contentsOf: URL(string: "http://127.0.0.1:\(port)/log")!, encoding: .utf8)
check(log == "NRC_POWER-ONOFF,NRC_VOLUP-ONOFF,NRC_ENTER-ONOFF,NRC_D7-ONOFF,NRC_RED-ONOFF,NRC_3D-ONOFF", "Tasten kamen an: \(log)")
check(VieraKey.allCases.allSatisfy { $0.rawValue.hasPrefix("NRC_") && $0.rawValue.hasSuffix("-ONOFF") }, "alle Tastencodes im NRC-Format")

// Lautstärke / Stumm
try await tv.setVolume(17)
check(try await tv.volume() == 17, "Lautstärke setzen/lesen")
try await tv.setVolume(250)
check(try await tv.volume() == 100, "Lautstärke auf 100 begrenzt")
try await tv.setMute(true)
check(try await tv.muted(), "Stumm an")
try await tv.setMute(false)
check(try await tv.muted() == false, "Stumm aus")

// Fehlerfälle
do {
    try await tv.send("NRC_FORBIDDEN-ONOFF")
    check(false, "403 erkannt")
} catch VieraError.remoteDisabled {
    check(true, "403 → Hinweis „TV Remote einschalten“")
}
do {
    try await tv.send("kaputt")
    check(false, "SOAP-Fehler erkannt")
} catch VieraError.rejected(let code, let text) {
    check(code == 500 && text == "Invalid Action", "SOAP-Fehler → \(code) \(text ?? "-")")
}
let start = Date()
do {
    _ = try await VieraClient(host: "127.0.0.1", port: 1).info()
    check(false, "geschlossener Port erkannt")
} catch VieraError.unreachable(let why) {
    check(Date().timeIntervalSince(start) < 6, "nicht erreichbar → \(why)")
}

print(failures == 0 ? "\nAlles grün." : "\n\(failures) Fehler.")
exit(failures == 0 ? 0 : 1)
