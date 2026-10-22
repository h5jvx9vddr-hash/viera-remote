import AppIntents

enum TVCommand: String, AppEnum {
    case power, volumeUp, volumeDown, mute, channelUp, channelDown, input

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "TV-Taste"
    static var caseDisplayRepresentations: [TVCommand: DisplayRepresentation] = [
        .power: "Ein/Aus",
        .volumeUp: "Lauter",
        .volumeDown: "Leiser",
        .mute: "Stumm",
        .channelUp: "Programm hoch",
        .channelDown: "Programm runter",
        .input: "Eingang",
    ]

    var key: VieraKey {
        switch self {
        case .power: .power
        case .volumeUp: .volumeUp
        case .volumeDown: .volumeDown
        case .mute: .mute
        case .channelUp: .channelUp
        case .channelDown: .channelDown
        case .input: .input
        }
    }
}

struct PressTVKeyIntent: AppIntent {
    static var title: LocalizedStringResource = "TV-Taste drücken"
    static var description = IntentDescription("Drückt eine Taste am gekoppelten Panasonic-Fernseher.")

    @Parameter(title: "Taste")
    var command: TVCommand

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$command) am Fernseher drücken")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let tv = SavedTV.load() else { throw VieraError.notPaired }
        do {
            try await VieraClient(host: tv.host).send(command.key.rawValue)
        } catch VieraError.unreachable(let why) where command == .power {
            guard let mac = tv.mac else { throw VieraError.unreachable(why) }
            for _ in 0..<3 { await WakeOnLAN.send(mac: mac, host: tv.host) }
            return .result(dialog: "Einschaltsignal gesendet.")
        }
        return .result(dialog: "Erledigt.")
    }
}

struct VieraShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PressTVKeyIntent(),
            phrases: [
                "\(.applicationName) \(\.$command)",
                "\(\.$command) mit \(.applicationName)",
            ],
            shortTitle: "TV-Taste",
            systemImageName: "av.remote"
        )
    }
}
