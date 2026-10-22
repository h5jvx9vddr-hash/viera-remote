import SwiftUI

struct SetupView: View {
    @Environment(TVStore.self) private var store
    @State private var ip = UserDefaults.standard.string(forKey: "viera.lastIP") ?? ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "av.remote.fill")
                            .font(.system(size: 46))
                            .foregroundStyle(Color.accentColor)
                        Text("Fernseher koppeln").font(.title2.weight(.bold))
                        Text("Einmal die feste IP deines Panasonic VIERA eingeben – danach steuerst du ihn direkt aus der App.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section {
                    TextField("192.168.178.40", text: $ip)
                        .keyboardType(.decimalPad)
                        .font(.title3.monospacedDigit())
                        .onSubmit { Task { await pair() } }
                } header: {
                    Text("IP-Adresse des Fernsehers")
                } footer: {
                    Text("Steht am TV unter Menü → Netzwerk → Netzwerkstatus. Im Router als feste IP vergeben, damit sie sich nicht ändert.")
                }

                Section {
                    Button {
                        Task { await pair() }
                    } label: {
                        HStack {
                            Spacer()
                            if busy { ProgressView() } else { Text("Koppeln").bold() }
                            Spacer()
                        }
                    }
                    .disabled(busy || ip.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Section("Vorher am Fernseher") {
                    HelpSteps()
                }
            }
            .navigationTitle("VIERA")
        }
    }

    private func pair() async {
        guard !busy else { return }
        busy = true
        error = nil
        defer { busy = false }
        do {
            try await store.pair(ip)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct HelpSteps: View {
    private let steps = [
        ("power", "Fernseher einschalten. iPhone und TV müssen im selben Netz sein (WLAN oder LAN am Router)."),
        ("network", "Menü → Netzwerk → Netzwerk-Link-Einstellungen → „TV Remote“ auf Ein (je nach Software-Stand auch „TV Remote App-Einstellungen“)."),
        ("number", "IP ablesen: Menü → Netzwerk → Netzwerkstatus."),
        ("lock.shield", "Beim ersten Koppeln fragt iOS nach „Lokales Netzwerk“ → Erlauben. Klappt der erste Versuch nicht, einfach nochmal auf Koppeln tippen."),
    ]

    var body: some View {
        ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
            Label {
                Text(step.1).font(.subheadline)
            } icon: {
                Image(systemName: step.0).foregroundStyle(Color.accentColor)
            }
        }
    }
}

struct SettingsView: View {
    @Environment(TVStore.self) private var store
    @State private var mac = ""
    @State private var testing = false
    @State private var confirmRemove = false

    private var macInvalid: Bool {
        !mac.trimmingCharacters(in: .whitespaces).isEmpty && VieraClient.formatMAC(mac) == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if let tv = store.tv {
                    Section("Fernseher") {
                        LabeledContent("Name", value: tv.info.name.replacingOccurrences(of: "_", with: " "))
                        LabeledContent("Modell", value: tv.info.model)
                        LabeledContent("IP-Adresse", value: tv.host)
                        LabeledContent("Status", value: store.statusText)
                        Button {
                            Task {
                                testing = true
                                await store.test()
                                testing = false
                            }
                        } label: {
                            HStack {
                                Text("Verbindung testen")
                                Spacer()
                                if testing { ProgressView() }
                            }
                        }
                        .disabled(testing)
                    }

                    Section {
                        TextField("AA:BB:CC:DD:EE:FF", text: $mac)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.body.monospaced())
                        if macInvalid {
                            Text("Keine gültige MAC-Adresse.").font(.footnote).foregroundStyle(.red)
                        }
                        Button {
                            Task { await store.wake() }
                        } label: {
                            HStack {
                                Text("Einschalten versuchen")
                                Spacer()
                                if store.waking { ProgressView() }
                            }
                        }
                        .disabled(store.waking || tv.mac == nil)
                    } header: {
                        Text("Einschalten übers Netzwerk")
                    } footer: {
                        Text("Ist der TV aus, schickt der Ein/Aus-Knopf ein Wake-on-LAN-Signal an diese MAC-Adresse (wird beim Koppeln automatisch ausgelesen). Der WT50 von 2012 schaltet sein Netzwerk im Standby aber meist komplett ab – dann geht Einschalten nur mit der normalen Fernbedienung. Ausschalten und alle anderen Tasten funktionieren immer.")
                    }

                    Section {
                        Text("In der Kurzbefehle-App gibt es die Aktion „TV-Taste drücken“ – z. B. für Siri: „VIERA Ein/Aus“ oder „VIERA Stumm“.")
                            .font(.subheadline)
                    } header: {
                        Text("Kurzbefehle & Siri")
                    }

                    Section {
                        Button("Fernseher entfernen", role: .destructive) { confirmRemove = true }
                    } footer: {
                        Text("Danach kannst du neu koppeln, z. B. wenn sich die IP geändert hat.")
                    }
                }

                Section("Hilfe") {
                    HelpSteps()
                }
            }
            .navigationTitle("Einstellungen")
            .onAppear { mac = store.tv?.mac ?? "" }
            .onChange(of: mac) { _, v in store.setMAC(v) }
            .confirmationDialog("Fernseher entfernen?", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Entfernen", role: .destructive) { store.remove() }
            }
        }
    }
}
