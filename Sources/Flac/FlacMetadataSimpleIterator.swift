@_exported import CFlac
@_exported import KwiftExtension

public final class FlacMetadataSimpleIterator {

  let iterator: OpaquePointer

  public init(path: String, readOnly: Bool, preserveFileStats: Bool) throws {
    iterator = try FLAC__metadata_simple_iterator_new().unwrap()
    try preconditionOrThrow(
      FLAC__metadata_simple_iterator_init(
        iterator, path,
        .init(cBool: readOnly), .init(cBool: preserveFileStats)
      ).cBool
    )
  }

  deinit {
    FLAC__metadata_iterator_delete(iterator)
  }
}

public extension FlacMetadataSimpleIterator {
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

  var currentBlockOffset: Int64 {
    FLAC__metadata_simple_iterator_get_block_offset(iterator)
  }

  var currentBlockType: FLAC__MetadataType {
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

  var currentBlockRaw: FlacStreamMetadata? {
    FLAC__metadata_simple_iterator_get_block(iterator)
      .map { FlacStreamMetadata($0) }
  }

  func currentBlock<T: FlacStreamMetadata>(as type: T.Type = T.self) -> T? {
    FLAC__metadata_simple_iterator_get_block(iterator)
      .map { T($0) }
  }

  var currentBlock: FlacStreamMetadata? {
    FLAC__metadata_simple_iterator_get_block(iterator).map { ptr in
      FlacStreamMetadata.autoCast(ptr, owner: nil)
    }
  }

  func set(block: FlacStreamMetadata, usePadding: Bool = true) throws {
    try preconditionOrThrow(
      FLAC__metadata_simple_iterator_set_block(
        iterator, block.ptr, .init(cBool: usePadding)
      ).cBool
    )
  }

  func insertAfterCurrentBlock(block: FlacStreamMetadata, usePadding: Bool = true) throws {
    try preconditionOrThrow(
      FLAC__metadata_simple_iterator_insert_block_after(
        iterator, block.ptr, .init(cBool: usePadding)
      ).cBool
    )
  }

  func deleteCurrentBlock(usePadding: Bool = true) throws {
    try preconditionOrThrow(
      FLAC__metadata_simple_iterator_delete_block(
        iterator, .init(cBool: usePadding)
      ).cBool
    )
  }

  var isLast: Bool {
    FLAC__metadata_simple_iterator_is_last(iterator).cBool
  }
}
