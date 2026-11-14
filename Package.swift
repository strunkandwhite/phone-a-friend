// swift-tools-version:5.9
import PackageDescription

var products: [Product] = [
    .library(name: "FriendQueue", targets: ["FriendQueue"]),
]

var targets: [Target] = [
    .target(name: "FriendQueue"),
    .testTarget(name: "FriendQueueTests", dependencies: ["FriendQueue"]),
]

let package = Package(
    name: "PhoneAFriend",
    platforms: [.macOS(.v13)],
    products: products,
    targets: targets
)
