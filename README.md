# VIERA Remote

iOS-Fernbedienung für Panasonic VIERA (gebaut für den WT50 von 2012). SwiftUI, iOS 26, XcodeGen.

- **Koppeln:** Einmal die feste IP eingeben. Die App liest `http://IP:55000/nrc/ddd.xml` (Name, Modell, MAC aus der UDN) und merkt sich den TV.
  Die Modelle bis 2018 brauchen keine PIN.
- **Steuern:** SOAP `X_SendKey` an `/nrc/control_0`. Lautstärke und Stumm laufen über UPnP RenderingControl (`/dmr/control_0`).
  Tastencodes stehen in `App/TV/Keys.swift`.
- **Einschalten:** Wake-on-LAN an IP und Subnetz-Broadcast. Der WT50 schaltet sein Netzwerk im Standby meist ab,
  deshalb klappt das wahrscheinlich nicht. Ausschalten geht immer.
- **Kurzbefehle:** Aktion „TV-Taste drücken“ (`App/Intents.swift`).

Am TV muss unter Menü → Netzwerk → Netzwerk-Link-Einstellungen „TV Remote“ auf Ein stehen.

## Build
- `.github/workflows/ios.yml` baut bei jedem Push auf `App/**` eine unsignierte IPA (Artefakt `VieraRemote-ipa`).
- `protocol.yml` (Ubuntu) testet `VieraClient` gegen einen simulierten TV (`Tests/mock_tv.py`).
- `screenshots.yml` (manuell) macht Demo-Screenshots. Startargumente: `-demo 1 -tab remote|digits|media|settings`, `-setup 1`.
- Icon: `design/icon.svg` → `node design/render.js App/Assets.xcassets/AppIcon.appiconset/icon-1024.png`
