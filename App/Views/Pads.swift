import SwiftUI

struct RemotePad: View {
    @Environment(TVStore.self) private var store
    @State private var volumeSheet = false

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                RKey(.power, symbol: "power", tint: .red, foreground: .white)
                RKey(.input, title: "AV")
                RKey(.tv, title: "TV")
                RKey(.connect, title: "Apps", symbol: "square.grid.2x2")
            }
            HStack(spacing: 12) {
                RKey(.menu, title: "Menü", height: 44)
                RKey(.info, symbol: "info.circle", height: 44)
                RKey(.option, title: "Option", height: 44)
            }
            DPad()
                .frame(maxWidth: 230)
            HStack(spacing: 12) {
                RKey(.back, title: "Zurück", symbol: "arrow.uturn.backward", height: 44)
                RKey(.guide, title: "Guide", height: 44)
                RKey(.exit, title: "Exit", height: 44)
            }
            HStack(spacing: 14) {
                Rocker(up: .volumeUp, down: .volumeDown, upSymbol: "plus", downSymbol: "minus",
                       label: "VOL", value: store.volume.map(String.init)) { volumeSheet = true }
                VStack(spacing: 10) {
                    RKey(.mute, symbol: store.muted ? "speaker.slash.fill" : "speaker.slash",
                         foreground: store.muted ? .red : .primary, height: 46)
                    RKey(.lastView, title: "Zuletzt", symbol: "arrow.left.arrow.right", height: 46)
                    RKey(.tools, title: "Tools", symbol: "wrench.and.screwdriver", height: 46)
                }
                Rocker(up: .channelUp, down: .channelDown, upSymbol: "chevron.up", downSymbol: "chevron.down", label: "P")
            }
            .frame(height: 158)
            ColorKeys()
        }
        .sheet(isPresented: $volumeSheet) {
            VolumeSheet().presentationDetents([.height(230)])
        }
    }
}

struct VolumeSheet: View {
    @Environment(TVStore.self) private var store
    @State private var value: Double = 0

    var body: some View {
        VStack(spacing: 14) {
            Text("Lautstärke").font(.headline)
            Text("\(Int(value))")
                .font(.system(size: 46, weight: .bold).monospacedDigit())
                .contentTransition(.numericText())
            HStack(spacing: 14) {
                Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                Slider(value: $value, in: 0...100, step: 1)
                Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .onAppear { value = Double(store.volume ?? 0) }
        .onChange(of: value) { _, v in store.setVolume(Int(v)) }
    }
}

struct DigitsPad: View {
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(1...3, id: \.self) { col in
                        let n = row * 3 + col
                        RKey(.digit(n), title: "\(n)", height: 64)
                    }
                }
            }
            HStack(spacing: 12) {
                RKey(.lastView, title: "Zuletzt", symbol: "arrow.left.arrow.right", height: 64)
                RKey(.d0, title: "0", height: 64)
                RKey(.enter, title: "OK", height: 64)
            }
            HStack(spacing: 12) {
                RKey(.channelDown, title: "P −", symbol: "chevron.down", repeats: true)
                RKey(.info, title: "Info", symbol: "info.circle")
                RKey(.channelUp, title: "P +", symbol: "chevron.up", repeats: true)
            }
            .padding(.top, 6)
            SectionLabel("Videotext")
            HStack(spacing: 12) {
                RKey(.text, title: "Videotext", symbol: "text.alignleft")
                RKey(.subtitles, title: "Untertitel", symbol: "captions.bubble")
                RKey(.guide, title: "Guide", symbol: "list.bullet.rectangle")
            }
            ColorKeys()
        }
    }
}

struct MediaPad: View {
    var body: some View {
        VStack(spacing: 12) {
            SectionLabel("Wiedergabe")
            HStack(spacing: 10) {
                RKey(.previous, symbol: "backward.end.fill")
                RKey(.rewind, symbol: "backward.fill", repeats: true)
                RKey(.play, symbol: "play.fill")
                RKey(.fastForward, symbol: "forward.fill", repeats: true)
                RKey(.next, symbol: "forward.end.fill")
            }
            HStack(spacing: 10) {
                RKey(.pause, symbol: "pause.fill")
                RKey(.stop, symbol: "stop.fill")
                RKey(.record, symbol: "record.circle", foreground: .red)
            }
            SectionLabel("Navigation")
            HStack(alignment: .center, spacing: 14) {
                VStack(spacing: 10) {
                    RKey(.back, title: "Zurück", symbol: "arrow.uturn.backward", height: 46)
                    RKey(.option, title: "Option", height: 46)
                }
                DPad().frame(maxWidth: 170)
                VStack(spacing: 10) {
                    RKey(.exit, title: "Exit", height: 46)
                    RKey(.menu, title: "Menü", height: 46)
                }
            }
            SectionLabel("Bild & Extras")
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    RKey(.threeD, title: "3D")
                    RKey(.aspect, title: "Format", symbol: "aspectratio")
                    RKey(.offTimer, title: "Sleep", symbol: "moon.zzz")
                }
                GridRow {
                    RKey(.sdCard, title: "SD-Karte", symbol: "sdcard")
                    RKey(.vieraLink, title: "VIERA Link", symbol: "link")
                    RKey(.input, title: "Eingang", symbol: "rectangle.on.rectangle")
                }
            }
        }
    }
}
