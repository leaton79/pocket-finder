// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DesktopFileWidget",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "DesktopFileWidgetCore", targets: ["DesktopFileWidgetCore"]),
        .executable(name: "DesktopFileWidget", targets: ["DesktopFileWidgetApp"])
    ],
    targets: [
        .target(name: "DesktopFileWidgetCore"),
        .executableTarget(
            name: "DesktopFileWidgetApp",
            dependencies: ["DesktopFileWidgetCore"]
        ),
        .testTarget(
            name: "DesktopFileWidgetCoreTests",
            dependencies: ["DesktopFileWidgetCore"]
        )
    ]
)
