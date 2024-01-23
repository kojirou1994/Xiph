// swift-tools-version: 5.8

import PackageDescription
import Foundation

let useSystemXiph: Bool
#if os(Linux)
useSystemXiph = true
#else
useSystemXiph = ProcessInfo.processInfo.environment["SYSTEM_XIPH"] != nil
#endif

var libFLAC: Target = .binaryTarget(name: "FLAC", path: "xcframework/FLAC.xcframework")
var libogg: Target = .binaryTarget(name: "ogg", path: "xcframework/ogg.xcframework")
var libopus: Target = .binaryTarget(name: "opus", path: "xcframework/opus.xcframework")
var libopusfile: Target = .binaryTarget(name: "opusfile", path: "xcframework/opusfile.xcframework")
var libopusurl: Target = .binaryTarget(name: "opusurl", path: "xcframework/opusurl.xcframework")

if useSystemXiph {
  libFLAC = .systemLibrary(
    name: libFLAC.name,
    pkgConfig: "flac"
  )
  libogg = .systemLibrary(
    name: libogg.name,
    pkgConfig: "ogg"
  )
  libopus = .systemLibrary(
    name: libopus.name,
    pkgConfig: "opus"
  )
  libopusfile = .systemLibrary(
    name: libopusfile.name,
    pkgConfig: "opusfile"
  )
  libopusurl = .systemLibrary(
    name: libopusurl.name,
    pkgConfig: "opusurl"
  )
}

let flac: Target = .target(
  name: "SwiftFlac",
  dependencies: [
    .target(name: libFLAC.name),
    .product(name: "CUtility", package: "CUtility"),
    .product(name: "Precondition", package: "Precondition"),
  ]
)

let opus: Target = .target(
  name: "SwiftOpus",
  dependencies: [
    .target(name: libopus.name),
    .target(name: libopusfile.name),
    .product(name: "CUtility", package: "CUtility"),
    .product(name: "Precondition", package: "Precondition"),
  ]
)

//#if OGG_FLAC
flac.dependencies.append(.target(name: libogg.name))
//#endif
opus.dependencies.append(.target(name: libogg.name))

let package = Package(
  name: "Xiph",
  platforms: [
    .macOS(.v10_15),
    .iOS(.v14),
    .tvOS(.v14),
    .watchOS(.v7),
  ],
  products: [
    .library(name: "Xiph", targets: [flac.name, opus.name]),
    .library(name: flac.name, targets: [flac.name]),
    .library(name: opus.name, targets: [opus.name]),
    .library(name: libFLAC.name, targets: [libFLAC.name]),
    .library(name: libogg.name, targets: [libogg.name]),
    .library(name: libopus.name, targets: [libopus.name]),
    .library(name: libopusfile.name, targets: [libopusfile.name]),
    .library(name: libopusurl.name, targets: [libopusurl.name]),
    .library(name: "ReplayGainAnalysis", targets: ["ReplayGainAnalysis"]),
  ],
  dependencies: [
    .package(url: "https://github.com/kojirou1994/Precondition.git", from: "1.0.0"),
    .package(url: "https://github.com/kojirou1994/CUtility.git", from: "0.1.0"),
  ],
  targets: [
    // C libs
    libFLAC,
    libogg,
    libopus,
    libopusfile,
    libopusurl,
    .target(name: "CReplayGainAnalysis"),

    // Swift
    flac,
    opus,
    .target(name: "ReplayGainAnalysis", dependencies: ["CReplayGainAnalysis"]),

    // Tests
    .testTarget(
      name: "FlacTests",
      dependencies: [
        .target(name: flac.name)
      ]
    ),
    .testTarget(
      name: "OpusTests",
      dependencies: [
        .target(name: opus.name),
        .target(name: libopusurl.name),
      ]
    ),
  ]
)
