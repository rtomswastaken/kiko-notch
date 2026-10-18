// swift-tools-version: 5.9
import PackageDescription
import Foundation

// Portable developer directory resolution for host plugins (SwiftUIMacros) and XCTest
let developerDir: String? = {
    if let env = ProcessInfo.processInfo.environment["DEVELOPER_DIR"], FileManager.default.fileExists(atPath: env) {
        return env
    }
    let standardPaths = [
        "/Applications/Xcode.app/Contents/Developer",
        "/Applications/Xcode-beta.app/Contents/Developer"
    ]
    return standardPaths.first(where: { FileManager.default.fileExists(atPath: $0) })
}()

var baseSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("BareSlashRegexLiterals")
]

if let dev = developerDir {
    let plugins = dev + "/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins"
    if FileManager.default.fileExists(atPath: plugins) {
        baseSwiftSettings.append(.unsafeFlags(["-plugin-path", plugins]))
    }
}

var testSwiftSettings: [SwiftSetting] = baseSwiftSettings
var testLinkerSettings: [LinkerSetting] = []

if let dev = developerDir {
    let frameworks = dev + "/Platforms/MacOSX.platform/Developer/Library/Frameworks"
    let usrLib = dev + "/Platforms/MacOSX.platform/Developer/usr/lib"
    if FileManager.default.fileExists(atPath: frameworks) {
        testSwiftSettings.append(.unsafeFlags(["-F", frameworks, "-I", usrLib]))
        testLinkerSettings.append(.unsafeFlags([
            "-F", frameworks,
            "-framework", "XCTest",
            "-Xlinker", usrLib + "/libXCTestSwiftSupport.dylib",
            "-Xlinker", "-rpath", "-Xlinker", usrLib,
            "-Xlinker", "-rpath", "-Xlinker", frameworks
        ]))
    }
}

let package = Package(
    name: "KikoNotch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "KikoNotch",
            targets: ["KikoNotch"]
        ),
        .library(
            name: "KikoNotchKit",
            targets: ["KikoNotchKit"]
        ),
        .executable(
            name: "KikoNotchTests",
            targets: ["KikoNotchTests"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "KikoNotchKit",
            dependencies: [],
            path: "Sources/KikoNotchKit",
            swiftSettings: baseSwiftSettings
        ),
        .executableTarget(
            name: "KikoNotch",
            dependencies: ["KikoNotchKit"],
            path: "Sources/KikoNotchApp",
            swiftSettings: baseSwiftSettings
        ),
        .executableTarget(
            name: "KikoNotchTests",
            dependencies: ["KikoNotchKit"],
            path: "Tests/KikoNotchTests",
            swiftSettings: testSwiftSettings,
            linkerSettings: testLinkerSettings
        )
    ]
)
