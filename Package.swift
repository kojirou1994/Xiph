// swift-tools-version:5.3

import PackageDescription

#if os(Linux) || SYSTEM_XIPH
let libFLAC: Target = .systemLibrary(
  name: "FLAC",
  pkgConfig: "flac"
)
let libogg: Target = .systemLibrary(
  name: "ogg",
  pkgConfig: "ogg"
)
let libopus: Target = .systemLibrary(
  name: "opus",
  pkgConfig: "opus"
)
let libopusfile: Target = .systemLibrary(
  name: "opusfile",
  pkgConfig: "opusurl"
)
#else
let libFLAC: Target = .binaryTarget(name: "FLAC", path: "xcframework/FLAC_static.xcframework")
let libogg: Target = .binaryTarget(name: "ogg", path: "xcframework/ogg_static.xcframework")
let libopus: Target = .binaryTarget(name: "opus", path: "xcframework/opus_static.xcframework")
let libopusfile: Target = .binaryTarget(name: "opusfile", path: "xcframework/opusfile_static.xcframework")
let libopusurl: Target = .binaryTarget(name: "opusurl", path: "xcframework/opusurl_static.xcframework")
#endif

let flac: Target = .target(
  name: "SwiftFlac",
  dependencies: [
    .target(name: libFLAC.name),
    .product(name: "KwiftC", package: "Kwift"),
    .product(name: "Precondition", package: "Kwift"),
  ]
)

let opus: Target = .target(
  name: "SwiftOpus",
  dependencies: [
    .target(name: libopus.name),
    .target(name: libopusfile.name),
    .target(name: libopusurl.name),
    .product(name: "KwiftC", package: "Kwift"),
    .product(name: "Precondition", package: "Kwift"),
  ]
)

//#if OGG_FLAC
flac.dependencies.append(.target(name: libogg.name))
//#endif
opus.dependencies.append(.target(name: libogg.name))

let package = Package(
  name: "Xiph",
  platforms: [
    .macOS(.v11),
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
  ],
  dependencies: [
    .package(url: "https://github.com/kojirou1994/Kwift.git", from: "0.8.1")
  ],
  targets: [
    // C libs
    libFLAC,
    libogg,
    libopus,
    libopusfile,
    libopusurl,

    // Swift
    flac,
    opus,

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
        .target(name: opus.name)
      ]
    ),
  ]
)
