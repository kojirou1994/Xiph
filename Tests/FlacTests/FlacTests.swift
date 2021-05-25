import XCTest
@testable import SwiftFlac

final class FlacTests: XCTestCase {
  func testRead() throws {
    let iterator = try FlacMetadataSimpleIterator(path: "/Volumes/SAMSUNG_TF_64G/SAMSUNG/Downloads/001-1_f.flac", readOnly: true, preserveFileStats: true)
    print("Success")
    for _ in 1...100000 {
      _ = iterator.currentBlock
      Thread.sleep(forTimeInterval: 0.001)
    }
  }
}

final class FlacStreamMetadataTests: XCTestCase {

  func testDescription() {
    print(FLAC__MAX_METADATA_TYPE)
  }

  func testVorbis() throws {
    let meta = try FlacStreamMetadataVorbisComment()
    print(meta.vendorString)
    print(meta.commentsCount)
    dump(meta.copyAll())
//    try meta.resize(count: 1)
    try meta.append(comment: "ABCD=1")
    print(meta.commentsCount)
    dump(meta.copyAll())
  }

  func testEntry() throws {
    var entry = FLAC__StreamMetadata_VorbisComment_Entry()
//    var ptr: UnsafeMutablePointer<FLAC__StreamMetadata_VorbisComment_Entry>?
    try preconditionOrThrow(
      FLAC__metadata_object_vorbiscomment_entry_from_name_value_pair(
        &entry,
//        ptr,
        "ABCD", "VALUE").cBool
    )
  }

  func testMemory() throws {
    let str = "ABCD=VALUE"
    try str.withVorbisCommentEntry { entry in
      let (name, value) = try entry.toNameValue()
      XCTAssertEqual(name, "ABCD")
      XCTAssertEqual(value, "VALUE")

//      while true {
//        _ = try entry.toNameValue()
//      }
    }
    print(MemoryLayout<FLAC__StreamMetadata>.size)

    do {
      _ = try FlacStreamMetadataVorbisComment()
    }
  }

  func testPicture() throws {
    let meta = try FlacStreamMetadataPicture()
    XCTAssertEqual(meta.mimeType, "")
    let mime = "image/jpeg"
    XCTAssertNoThrow(try meta.set(mimeType: mime))
    XCTAssertEqual(meta.mimeType, mime)

    XCTAssertEqual(meta.description, "")
    let description = "ABCDEFG"
    XCTAssertNoThrow(try meta.set(description: description))
    XCTAssertEqual(meta.description, description)

    let data = [UInt8](repeating: 5, count: 100)
    XCTAssertNoThrow(try meta.set(data: data))
    XCTAssertTrue(data.elementsEqual(meta.data))
  }
}
