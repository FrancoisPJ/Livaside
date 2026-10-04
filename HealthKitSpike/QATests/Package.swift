// swift-tools-version:5.9
// Tests unitaires de la logique pure (agrégats, dates) hors du target app : `swift test` suffit,
// sans simulateur. Les sources sont des liens symboliques vers LivasideSpike/.
import PackageDescription

let package = Package(
    name: "QATests",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "QACore"),
        .testTarget(name: "QACoreTests", dependencies: ["QACore"]),
    ]
)
