import SwiftUI
import Observation

struct SavedTV: Codable, Equatable {
    var host: String
    var info: TVInfo
    /// Für Wake-on-LAN; Vorgabe aus der UDN, in den Einstellungen änderbar.
    var mac: String?
}

extension SavedTV {
    static let key = "viera.tv"

    static func load() -> SavedTV? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(SavedTV.self, from: $0) }
    }

    func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

@MainActor @Observable
final class TVStore {
    var tv: SavedTV? {
        didSet {
            guard !demo else { return }
            if let tv { tv.save() } else { UserDefaults.standard.removeObject(forKey: SavedTV.key) }
        }
    }
    var online: Bool?
    var volume: Int?
    var muted = false
    var waking = false
    var toast: String?

    let demo: Bool
    private var queue: Task<Void, Never>?
    private var pending = 0
    private var pollTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var volumeTask: Task<Void, Never>?
    private var volumeSetAt = Date.distantPast

    init() {
        let args = ProcessInfo.processInfo.arguments
        demo = args.contains("-demo")
        if demo {
            if !args.contains("-setup") {
                tv = SavedTV(host: "192.168.178.40",
                             info: TVInfo(name: "VIERA_WT50", model: "TX-L55WT50E", mac: "A8:13:74:D9:A1:B2"),
                             mac: "A8:13:74:D9:A1:B2")
                online = true
                volume = 18
            }
        } else {
            tv = SavedTV.load()
        }
    }

    private var client: VieraClient? { tv.map { VieraClient(host: $0.host) } }

    var statusText: String {
        if waking { return "wird eingeschaltet …" }
        switch online {
        case .some(true): return "verbunden"
        case .some(false): return "nicht erreichbar"
        case .none: return "verbinde …"
        }
    }

    // MARK: Koppeln

    func pair(_ raw: String) async throws {
        guard let host = VieraClient.normalize(raw) else { throw VieraError.invalidHost }
        UserDefaults.standard.set(host, forKey: "viera.lastIP")
        let info = try await VieraClient(host: host).info()
        tv = SavedTV(host: host, info: info, mac: info.mac)
        online = true
        await refresh()
    }

    func remove() {
        tv = nil
        online = nil
        volume = nil
        muted = false
    }

    func setMAC(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { tv?.mac = nil } else if let mac = VieraClient.formatMAC(trimmed) { tv?.mac = mac }
    }

    // MARK: Tasten

    func press(_ key: VieraKey) {
        Haptics.tap()
        guard !demo, let tv, let client else { return }
        // Bei Dauerdruck auf einen langsamen/aus­geschalteten TV keinen Rückstau aufbauen.
        guard pending < 4 else { return }
        pending += 1
        let previous = queue
        queue = Task {
            await previous?.value
            defer { pending -= 1 }
            do {
                try await client.send(key.rawValue)
                online = true
                if key == .volumeUp || key == .volumeDown || key == .mute { await refreshVolume() }
            } catch {
                if case VieraError.unreachable = error {
                    online = false
                    if key == .power, tv.mac != nil {
                        await wake()
                        return
                    }
                }
                show(error.localizedDescription)
            }
        }
    }

    func setVolume(_ n: Int) {
        guard n != volume else { return }
        volume = n
        volumeSetAt = .now
        guard !demo, let client else { return }
        volumeTask?.cancel()
        volumeTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            do { try await client.setVolume(n) } catch { show(error.localizedDescription) }
        }
    }

    /// Wake-on-LAN, danach bis zu 20 s auf den TV warten.
    func wake() async {
        guard let tv, let client else { return }
        guard let mac = tv.mac else {
            show("Der Fernseher ist aus oder nicht erreichbar. Zum Einschalten übers Netz in den Einstellungen die MAC-Adresse eintragen.")
            return
        }
        if demo { return }
        waking = true
        defer { waking = false }
        for _ in 0..<3 {
            await WakeOnLAN.send(mac: mac, host: tv.host)
        }
        for _ in 0..<10 {
            try? await Task.sleep(for: .seconds(2))
            if (try? await client.info()) != nil {
                online = true
                show("Fernseher ist an.")
                await refresh()
                return
            }
        }
        show("Keine Antwort. Der WT50 schaltet sein Netzwerk im Standby meist ab – dann bitte einmal mit der normalen Fernbedienung einschalten.")
    }

    // MARK: Status

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(online == true ? 4 : 6))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() async {
        guard !demo, let client else { return }
        do {
            let v = try await client.volume()
            // Gerade per Regler gesetzt → nicht vom alten Wert überschreiben lassen.
            if Date.now.timeIntervalSince(volumeSetAt) > 1.5 { volume = v }
            muted = (try? await client.muted()) ?? muted
            online = true
        } catch {
            // Manche TVs haben den Renderer abgeschaltet – dann zählt die Gerätebeschreibung.
            online = (try? await client.info()) != nil
        }
    }

    func test() async {
        await refresh()
        show(online == true ? "Verbindung steht." : "Fernseher antwortet nicht.")
    }

    private func refreshVolume() async {
        guard let client else { return }
        if let v = try? await client.volume() { volume = v }
        if let m = try? await client.muted() { muted = m }
    }

    func show(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            toast = nil
        }
    }
}
