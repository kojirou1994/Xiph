/*
 https://xiph.org/flac/api/group__flac__metadata__level1.html
 */

import FLAC
import Precondition
import CUtility

extension Flac {
  public struct MetadataSimpleIterator: ~Copyable {

    let iterator: OpaquePointer

    public init() throws {
      iterator = try FLAC__metadata_simple_iterator_new().unwrap()
      //  path: String, readOnly: Bool, preserveFileStats: Bool
      //    try preconditionOrThrow(
      //      FLAC__metadata_simple_iterator_init(
      //        iterator, path,
      //        .init(cBool: readOnly), .init(cBool: preserveFileStats)
      //      ).cBool
      //    )
    }

    deinit {
      FLAC__metadata_iterator_delete(iterator)
    }
  }
}

public extension Flac.MetadataSimpleIterator {
  var isWritable: Bool {
    FLAC__metadata_simple_iterator_is_writable(iterator).cBool
  }

  var status: UInt32 {
    FLAC__metadata_simple_iterator_status(iterator).rawValue
  }

  func next() -> Bool {
    FLAC__metadata_simple_iterator_next(iterator).cBool
  }

  func prev() -> Bool {
    FLAC__metadata_simple_iterator_prev(iterator).cBool
  }

  func seekToFirstBlock() {
    while prev() {

    }
  }

  var currentBlockOffset: Int {
    numericCast(FLAC__metadata_simple_iterator_get_block_offset(iterator))
  }

  var currentBlockType: Flac.StreamMetadata.MetadataType {
    FLAC__metadata_simple_iterator_get_block_type(iterator)
  }

  var currentBlockLength: UInt32 {
    FLAC__metadata_simple_iterator_get_block_length(iterator)
  }

  func getApplicationID() throws -> [UInt8] {
    var id = [UInt8](repeating: 0, count: 4)
    try preconditionOrThrow(
      FLAC__metadata_simple_iterator_get_application_id(iterator, &id).cBool
    )
    return id
  }

  func getCurrentBlock() throws -> Flac.StreamMetadata {
    try .init(FLAC__metadata_simple_iterator_get_block(iterator).unwrap())
  }

  func set(block: borrowing Flac.StreamMetadata, usePadding: Bool = true) -> Bool {
    FLAC__metadata_simple_iterator_set_block(
      iterator, block.ptr, .init(cBool: usePadding)
    ).cBool
  }

  func insertAfterCurrentBlock(block: borrowing Flac.StreamMetadata, usePadding: Bool = true) -> Bool {
    FLAC__metadata_simple_iterator_insert_block_after(
      iterator, block.ptr, .init(cBool: usePadding)
    ).cBool
  }

  func deleteCurrentBlock(usePadding: Bool = true) -> Bool {
    FLAC__metadata_simple_iterator_delete_block(
      iterator, .init(cBool: usePadding)
    ).cBool
  }

  var isLast: Bool {
    FLAC__metadata_simple_iterator_is_last(iterator).cBool
  }
}
