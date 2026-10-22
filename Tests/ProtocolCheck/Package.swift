// swift-tools-version:5.9
import PackageDescription

// App/TV/VieraClient.swift + Keys.swift werden vor dem Build hierher kopiert (siehe protocol.yml).
let package = Package(
    name: "ProtocolCheck",
    targets: [.executableTarget(name: "ProtocolCheck")]
)
