import FLAC
import Precondition

extension Flac.MetadataChain {
  public struct Iterator: ~Copyable {

    internal let iterator: OpaquePointer
    internal let chain: OpaquePointer

    public init(chain: consuming Flac.MetadataChain) throws {
      iterator = try FLAC__metadata_iterator_new().unwrap()
      FLAC__metadata_iterator_init(iterator, chain.chain)
      self.chain = chain.take()
    }

    deinit {
      FLAC__metadata_iterator_delete(iterator)
      FLAC__metadata_chain_delete(chain)
    }
  }
}

public extension Flac.MetadataChain.Iterator {

  /// get chain back
  consuming func takeChain() -> Flac.MetadataChain {
    FLAC__metadata_iterator_delete(iterator)
    let v = Flac.MetadataChain(chain)
    discard self
    return v
  }

  mutating func withCurrentBlock<R>(_ body: (inout Flac.StreamMetadata) throws -> R) rethrows -> R {
    let blockPtr = FLAC__metadata_iterator_get_block(iterator).unsafelyUnwrapped
    var block = Flac.StreamMetadata(blockPtr)

    do {
      let result = try body(&block)
      let newPtr = block.take()
      assert(blockPtr == newPtr, "replacing metadata is useless! use functions.")
      return result
    } catch {
      _ = block.take()
      throw error
    }
  }

  mutating func next() -> Bool {
    FLAC__metadata_iterator_next(iterator).cBool
  }

  mutating func prev() -> Bool {
    FLAC__metadata_iterator_prev(iterator).cBool
  }

  var currentBlockType: Flac.StreamMetadata.MetadataType {
    FLAC__metadata_iterator_get_block_type(iterator)
  }

  mutating func set(block: consuming Flac.StreamMetadata) -> Bool {
    FLAC__metadata_iterator_set_block(
      iterator, block.take()
    ).cBool
  }

  mutating func delete(replaceWithPadding: Bool = true) -> Bool {
    FLAC__metadata_iterator_delete_block(
      iterator, .init(cBool: replaceWithPadding)
    ).cBool
  }

  mutating func insertAfterCurrentBlock(_ block: consuming Flac.StreamMetadata) -> Bool {
    FLAC__metadata_iterator_insert_block_after(iterator, block.take()).cBool
  }

  mutating func insertBeforeCurrentBlock(_ block: consuming Flac.StreamMetadata) -> Bool {
    FLAC__metadata_iterator_insert_block_before(iterator, block.take()).cBool
  }

}
