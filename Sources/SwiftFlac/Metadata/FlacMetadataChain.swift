import FLAC
import CUtility

extension Flac {
  public struct MetadataChain: ~Copyable {
    internal init(_ chain: OpaquePointer) {
      self.chain = chain
    }

    let chain: OpaquePointer

    public init() throws {
      chain = try FLAC__metadata_chain_new().unwrap()
    }

    deinit {
      FLAC__metadata_chain_delete(chain)
    }
  }
}

public extension Flac.MetadataChain {

  internal consuming func take() -> OpaquePointer {
    let v = chain
    discard self
    return v
  }

  consuming func iterator() -> Iterator {
    try! .init(chain: self)
  }
}

public extension Flac.MetadataChain {

  typealias Status = FLAC__Metadata_ChainStatus

  var status: Status {
    FLAC__metadata_chain_status(chain)
  }

  mutating func read(filename: String) -> Bool {
    FLAC__metadata_chain_read(chain, filename).cBool
  }

  mutating func readOGG(filename: String) -> Bool {
    FLAC__metadata_chain_read_ogg(chain, filename).cBool
  }

  func checkIfTempFileNeeded(usePadding: Bool) -> Bool {
    FLAC__metadata_chain_check_if_tempfile_needed(chain, .init(cBool: usePadding)).cBool
  }

  func write(usePadding: Bool, preserveFileStats: Bool) -> Bool {
    FLAC__metadata_chain_write(chain, .init(cBool: usePadding), .init(cBool: preserveFileStats)).cBool
  }

  mutating func mergePadding() {
    FLAC__metadata_chain_merge_padding(chain)
  }

  mutating func sortPadding() {
    FLAC__metadata_chain_sort_padding(chain)
  }
}

public extension Flac.MetadataChain.Status {
//  var string: StaticCString {
//    .init(cString: FLAC__Metadata_ChainStatusString[Int(rawValue)])
//  }
}

public extension Flac.MetadataChain.Status {
  static var ok: Self { FLAC__METADATA_CHAIN_STATUS_OK }
}
