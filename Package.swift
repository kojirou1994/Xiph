// swift-tools-version:5.0

import PackageDescription

let xiphTargets = ["Flac", "Opus"]

let package = Package(
  name: "Xiph",
  products: [
    .library(
      name: "Xiph",
      targets: xiphTargets),
    .library(
      name: "Flac",
      targets: ["Flac"]),
    .library(
      name: "Opus",
      targets: ["Opus"]),
    .library(name: "CFlac", targets: ["CFlac"]),
    .library(name: "COgg", targets: ["COgg"]),
    .library(name: "COpus", targets: ["COpus"]),
    .library(name: "COpusfile", targets: ["COpusfile"]),
  ],
  dependencies: [
    .package(url: "https://github.com/kojirou1994/Kwift.git", from: "0.8.1")
  ],
  targets: [
    // FLAC
    .systemLibrary(
      name: "CFlac",
      pkgConfig: "flac",
      providers: [.brew(["flac"])]
    ),
    .target(
      name: "Flac",
      dependencies: [
        "CFlac",
        .product(name: "KwiftExtension", package: "Kwift")
      ]
    ),

    // Ogg
    .systemLibrary(
      name: "COgg",
      pkgConfig: "ogg"
    ),

    // Opus
    .systemLibrary(
      name: "COpus",
      pkgConfig: "opus"
    ),
    .systemLibrary(
      name: "COpusfile",
      pkgConfig: "opusfile"
    ),
    .target(
      name: "Opus",
      dependencies: [
        "COpus",
        "COpusfile",
        .product(name: "KwiftExtension", package: "Kwift")
      ]
    ),

    // Tests
    .testTarget(
      name: "FlacTests",
      dependencies: ["Flac"]
    ),
    .testTarget(
      name: "OpusTests",
      dependencies: ["Opus"]
    ),
  ]
)
