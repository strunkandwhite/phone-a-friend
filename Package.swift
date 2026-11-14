// swift-tools-version:5.9
import PackageDescription

var products: [Product] = [
    .library(name: "FriendQueue", targets: ["FriendQueue"]),
]

var targets: [Target] = [
    .target(name: "FriendQueue"),
    .testTarget(name: "FriendQueueTests", dependencies: ["FriendQueue"]),
]

// The menu bar app needs AppKit and SwiftUI, so it only exists when building on macOS;
// Linux builds see just the library and its tests.
#if os(macOS)
targets.append(.executableTarget(name: "PhoneAFriend", dependencies: ["FriendQueue"]))
products.append(.executable(name: "PhoneAFriend", targets: ["PhoneAFriend"]))
#endif

let package = Package(
    name: "PhoneAFriend",
    platforms: [.macOS(.v13)],
    products: products,
    targets: targets
)
