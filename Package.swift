// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "mechasqueak",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/miroslavkovac/Lingo.git", from: Version(3, 0, 5)),
        .package(url: "https://github.com/IBM-Swift/SwiftyRequest.git", from: Version(3, 1, 0)),
        .package(name: "SwiftKueryORM", url: "https://github.com/IBM-Swift/Swift-Kuery-ORM.git", from: "0.6.1"),
        .package(name: "SwiftKueryPostgreSQL", url: "https://github.com/IBM-Swift/Swift-Kuery-PostgreSQL.git", from: "2.1.1"),
        .package(url: "https://github.com/apple/swift-nio.git", from: Version(2, 22, 0)),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: Version (2, 9, 1)),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: Version(1, 7, 0)),
        .package(url: "https://github.com/crossroadlabs/Regex.git", from: Version(1, 2, 0)),
        .package(url: "https://github.com/mattpolzin/JSONAPI.git", from: Version(4, 0, 0)),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: Version(1, 3, 1)),
        //.package(path: "../IRCKit")
        .package(name: "IRCKit", url: "https://github.com/FuelRats/irckit.git", from: Version(0, 0, 1))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "mechasqueak",
            dependencies: [
                .product(name: "Lingo", package: "Lingo"),
                .product(name: "SwiftyRequest", package: "SwiftyRequest"),
                "SwiftKueryORM",
                "SwiftKueryPostgreSQL",
                "CryptoSwift",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "NIOExtras", package: "swift-nio-extras"),
                .product(name: "Regex", package: "Regex"),
                .product(name: "JSONAPI", package: "JSONAPI"),
                .product(name: "IRCKit", package: "IRCKit")
            ]
        ),
        .testTarget(
            name: "mechasqueakTests",
            dependencies: ["mechasqueak"]),
    ]
)
