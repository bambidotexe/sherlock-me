// swift-tools-version:5.10
import PackageDescription

// TEMPLATE: the four names SwiftPM cannot read from scripts/signing.env are the target names below and the
// directories under Sources/ and Tests/ they point at. scripts/new-app.sh renames all of them together.
let package = Package(
    name: "sherlockme",
    // Tools 5.10 has no `.v26`, so the target is spelled out. Not lower: SwiftPM records the deployment
    // target as the binary's SDK version, and AppKit draws the Liquid Glass design only for a binary whose
    // recorded SDK is 26 or later (the shared pitfalls).
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "SherlockMe", targets: ["SherlockMeApp"]),
    ],
    targets: [
        // Pure rules: Foundation and CoreGraphics only, and it never reads a clock. `PurityTests` fails the
        // build otherwise.
        .target(name: "SherlockMeCore"),
        // The only code that talks to the system.
        .target(name: "SherlockMePlatform", dependencies: ["SherlockMeCore"]),
        // The run loop, the windows and the wiring.
        .executableTarget(name: "SherlockMeApp", dependencies: ["SherlockMeCore", "SherlockMePlatform"]),
        // The Accessibility probe. It is never put in the bundle: scripts/make-app.sh copies one
        // executable, and this is not it. A command-line tool inherits the Accessibility grant of the
        // terminal that starts it, which is how the app's own windows are read while developing.
        .executableTarget(name: "axprobe", path: "Tools/axprobe"),
        // The Touch ID probe: what happens around a Touch ID key press, read off the unified log, and the
        // hold and lock calls the design rests on, tried on the owner's hardware. Never put in the bundle
        // either; every run ends by itself.
        .executableTarget(name: "touchprobe", path: "Tools/touchprobe"),
        .testTarget(name: "SherlockMeCoreTests", dependencies: ["SherlockMeCore"]),
        // SherlockMeCore is declared explicitly: the platform tests use Core's own types, and relying on
        // SwiftPM's transitive module search path for that is incidental, not a guarantee.
        .testTarget(name: "SherlockMePlatformTests",
                    dependencies: ["SherlockMePlatform", "SherlockMeCore"]),
    ]
)
