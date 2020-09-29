import CFlac

public final class FlacMetadataChain {

  let chainPointer: OpaquePointer

  public init() throws {
    chainPointer = try FLAC__metadata_chain_new().unwrap()
  }

  deinit {
    FLAC__metadata_chain_delete(chainPointer)
  }
}

public extension FlacMetadataChain {
  var iterator: FlacMetadataIterator {
    try! .init(chain: self)
  }
}

public extension FlacMetadataChain {
  var status: FLAC__Metadata_ChainStatus {
    FLAC__metadata_chain_status(chainPointer)
  }

  func read(filename: String) throws {
    try preconditionOrThrow(
      FLAC__metadata_chain_read(chainPointer, filename).cBool
    )
  }

  func readOGG(filename: String) throws {
    try preconditionOrThrow(
      FLAC__metadata_chain_read_ogg(chainPointer, filename).cBool
    )
  }

  private func t() {

  }

  func checkIfNeedTempFile(usePadding: Bool) -> Bool {
    FLAC__metadata_chain_check_if_tempfile_needed(chainPointer, .init(cBool: usePadding)).cBool
  }

  func write(usePadding: Bool, preserveFileStats: Bool) throws {
    try preconditionOrThrow(
      FLAC__metadata_chain_write(chainPointer, .init(cBool: usePadding), .init(cBool: preserveFileStats)).cBool
    )
  }

  func mergePadding() {
    FLAC__metadata_chain_merge_padding(chainPointer)
  }

  func sortPadding() {
    FLAC__metadata_chain_sort_padding(chainPointer)
  }
}
