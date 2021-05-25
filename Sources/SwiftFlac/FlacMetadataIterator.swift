import FLAC
import Precondition

public final class FlacMetadataIterator {

  let iterator: OpaquePointer
  let chain: FlacMetadataChain

  public init(chain: FlacMetadataChain) throws {
    self.chain = chain
    iterator = try FLAC__metadata_iterator_new().unwrap(FlacError.malloc)
    FLAC__metadata_iterator_init(iterator, chain.chainPointer)
  }

  deinit {
    FLAC__metadata_iterator_delete(iterator)
  }
}

public extension FlacMetadataIterator {

  func next() -> Bool {
    FLAC__metadata_iterator_next(iterator).cBool
  }

  func prev() -> Bool {
    FLAC__metadata_iterator_prev(iterator).cBool
  }

  var currentBlockType: FLAC__MetadataType {
    FLAC__metadata_iterator_get_block_type(iterator)
  }

  var currentBlockRaw: FlacStreamMetadata {
    FlacStreamMetadata(FLAC__metadata_iterator_get_block(iterator), owner: self)
  }

  func currentBlock<T: FlacStreamMetadata>(as type: T.Type = T.self) -> T {
    T(FLAC__metadata_iterator_get_block(iterator), owner: self)
  }

  var currentBlock: FlacStreamMetadata {
    FlacStreamMetadata.autoCast(FLAC__metadata_iterator_get_block(iterator), owner: self)
  }

  func set(block: FlacStreamMetadata) throws {
    let used = try block.owner == nil ? block : block.clone()
    try preconditionOrThrow(
      FLAC__metadata_iterator_set_block(
        iterator, used.ptr
      ).cBool
    )
    used.owner = self
  }

  func delete(replaceWithPadding: Bool = true) throws {
    try preconditionOrThrow(
      FLAC__metadata_iterator_delete_block(
        iterator, .init(cBool: replaceWithPadding)
      ).cBool
    )
  }

  func insert(block: FlacStreamMetadata, afterCurrentBlock: Bool) throws {
    let used = try block.owner == nil ? block : block.clone()
    try preconditionOrThrow(
      (afterCurrentBlock ?
        FLAC__metadata_iterator_insert_block_after(iterator, block.ptr)
        :
        FLAC__metadata_iterator_insert_block_before(iterator, block.ptr)
      )
      .cBool
    )
    used.owner = self
  }

}
