import Foundation
import CFlac
import Precondition

public enum FlacDecoderInitError: Error {
  case unsupportedContainer
  //  case invalidCallbacks
  case memoryAllocation
  case errorOpeningFile
  //  case alreadyInitialized
  case unknown(UInt32)

  init(_ v: FLAC__StreamDecoderInitStatus) {
    switch v {
    case FLAC__STREAM_DECODER_INIT_STATUS_UNSUPPORTED_CONTAINER:
      self = .unsupportedContainer
    case FLAC__STREAM_DECODER_INIT_STATUS_MEMORY_ALLOCATION_ERROR:
      self = .memoryAllocation
    case FLAC__STREAM_DECODER_INIT_STATUS_ERROR_OPENING_FILE:
      self = .errorOpeningFile
    case FLAC__STREAM_DECODER_INIT_STATUS_OK,
         FLAC__STREAM_DECODER_INIT_STATUS_INVALID_CALLBACKS,
         FLAC__STREAM_DECODER_INIT_STATUS_ALREADY_INITIALIZED:
      fatalError("Should never happen!")
    default:
      // for future unknown error
      assertionFailure("Unknown decoder init status: \(v.rawValue)")
      self = .unknown(v.rawValue)
    }

  }
}

public enum FlacDecoderState {
  case searchForMetadata
  case readMetadata
  case searchForFrameSync
  case readFrame
  case endOfStream
  case oggError
  case seekError
  case aborted
  case memoryAllocationError
  case uninitialized
  case unknown(UInt32)

  init(_ state: FLAC__StreamDecoderState) {
    switch state {
    case FLAC__STREAM_DECODER_SEARCH_FOR_METADATA:
      self = .searchForMetadata
    case FLAC__STREAM_DECODER_READ_METADATA:
      self = .readMetadata
    case FLAC__STREAM_DECODER_SEARCH_FOR_FRAME_SYNC:
      self = .searchForFrameSync
    case FLAC__STREAM_DECODER_READ_FRAME:
      self = .readFrame
    case FLAC__STREAM_DECODER_END_OF_STREAM:
      self = .endOfStream
    case FLAC__STREAM_DECODER_OGG_ERROR:
      self = .oggError
    case FLAC__STREAM_DECODER_SEEK_ERROR:
      self = .seekError
    case FLAC__STREAM_DECODER_ABORTED:
      self = .aborted
    case FLAC__STREAM_DECODER_MEMORY_ALLOCATION_ERROR:
      self = .memoryAllocationError
    case FLAC__STREAM_DECODER_UNINITIALIZED:
      assertionFailure("Should never happen!")
      self = .uninitialized
    default:
      // for future unknown error
      assertionFailure("Unknown decoder state: \(state.rawValue)")
      self = .unknown(state.rawValue)
    }
  }
}

// MARK: Base Callbacks
public protocol FlacDecoderDelegate {
  func writeCallback(frame: UnsafePointer<FLAC__Frame>?, buffers: UnsafePointer<UnsafePointer<FLAC__int32>?>?) -> Bool
  func metadataCallback(metadata: UnsafePointer<FLAC__StreamMetadata>)
  func errorCallback(status: FLAC__StreamDecoderErrorStatus)
}

fileprivate func writeCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, frame: UnsafePointer<FLAC__Frame>?, buffers: UnsafePointer<UnsafePointer<FLAC__int32>?>?, client: UnsafeMutableRawPointer?) -> FLAC__StreamDecoderWriteStatus {
  let swiftDecoder = unsafeBitCast(client!, to: FlacDecoder.self)
  let success = swiftDecoder.delegate?.writeCallback(frame: frame, buffers: buffers) ?? true
  return success ? FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE
    : FLAC__STREAM_DECODER_WRITE_STATUS_ABORT
}

fileprivate func metadataCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, metadata: UnsafePointer<FLAC__StreamMetadata>?, client: UnsafeMutableRawPointer?) {
  let swiftDecoder = unsafeBitCast(client!, to: FlacDecoder.self)
  swiftDecoder.delegate?.metadataCallback(metadata: metadata!)
}

fileprivate func errorCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, status: FLAC__StreamDecoderErrorStatus, client: UnsafeMutableRawPointer?)  {
  let swiftDecoder = unsafeBitCast(client!, to: FlacDecoder.self)
  swiftDecoder.delegate?.errorCallback(status: status)
}

// MARK: Stream Callbacks
public protocol FlacDecoderStreamDelegate {
  func readCallback(buffer: UnsafeMutablePointer<FLAC__byte>?, bytes: UnsafeMutablePointer<Int>?) -> FLAC__StreamDecoderReadStatus
  func seekCallback(absoluteByteOffset: UInt64) -> FLAC__StreamDecoderSeekStatus
  func tellCallback(absoluteByteOffset: UnsafeMutablePointer<FLAC__uint64>?) -> FLAC__StreamDecoderTellStatus
  func lengthCallback(streamLength: UnsafeMutablePointer<FLAC__uint64>?) -> FLAC__StreamDecoderLengthStatus
  func eofCallback() -> Bool
}

fileprivate func readCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, buffer: UnsafeMutablePointer<FLAC__byte>?, bytes: UnsafeMutablePointer<Int>?, client: UnsafeMutableRawPointer?) -> FLAC__StreamDecoderReadStatus {
  let swiftDecoder = unsafeBitCast(client!, to: FlacDecoder.self)
  switch swiftDecoder.input {
  case .stream(let delegate):
    return delegate.readCallback(buffer: buffer, bytes: bytes)
  default:
    fatalError()
  }
}

fileprivate func seekCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, absolute_byte_offset: UInt64, client: UnsafeMutableRawPointer?) -> FLAC__StreamDecoderSeekStatus {
  let swiftDecoder = unsafeBitCast(client!, to: FlacDecoder.self)
  switch swiftDecoder.input {
  case .stream(let delegate):
    return delegate.seekCallback(absoluteByteOffset: absolute_byte_offset)
  default:
    fatalError()
  }
}

fileprivate func tellCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, absolute_byte_offset: UnsafeMutablePointer<FLAC__uint64>?, client: UnsafeMutableRawPointer?) -> FLAC__StreamDecoderTellStatus {
  let swiftDecoder = unsafeBitCast(client!, to: FlacDecoder.self)
  switch swiftDecoder.input {
  case .stream(let delegate):
    return delegate.tellCallback(absoluteByteOffset: absolute_byte_offset)
  default:
    fatalError()
  }
}

fileprivate func lengthCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, streamLength: UnsafeMutablePointer<FLAC__uint64>?, client: UnsafeMutableRawPointer?) -> FLAC__StreamDecoderLengthStatus {
  let swiftDecoder = unsafeBitCast(client!, to: FlacDecoder.self)
  switch swiftDecoder.input {
  case .stream(let delegate):
    return delegate.lengthCallback(streamLength: streamLength)
  default:
    fatalError()
  }
}

fileprivate func eofCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, client: UnsafeMutableRawPointer?) -> FLAC__bool {
  let swiftDecoder = unsafeBitCast(client!, to: FlacDecoder.self)
  switch swiftDecoder.input {
  case .stream(let delegate):
    return delegate.eofCallback().flacBool
  default:
    fatalError()
  }
}

public final class FlacDecoder {

  private let decoder: UnsafeMutablePointer<FLAC__StreamDecoder>

  public let input: Input

  public let delegate: FlacDecoderDelegate?

  public enum Input {
    case file(String)
    case cfile(UnsafeMutablePointer<FILE>)
    case oggFile(String)
    case oggCFile(UnsafeMutablePointer<FILE>)
    case stream(FlacDecoderStreamDelegate)
    case oggStream(FlacDecoderStreamDelegate)
  }

  ///
  /// - Parameters:
  ///   - input: input enum
  ///   - delegate: callback delegate
  /// - Throws: FlacDecoderInitError
  public init(input: Input, delegate: FlacDecoderDelegate?, options: [DecoderOption]) throws {
    decoder = try FLAC__stream_decoder_new()
      .unwrap(FlacDecoderInitError.memoryAllocation)
    self.delegate = delegate
    self.input = input

    options.forEach { option in
      let result: FLAC__bool
      switch option {
      case .oggSerialNumber(let number):
        result = FLAC__stream_decoder_set_ogg_serial_number(decoder, number)
      case .md5CheckingEnabled:
        result = FLAC__stream_decoder_set_md5_checking(decoder, true.flacBool)
      case .metadataRespond(let type):
        result = FLAC__stream_decoder_set_metadata_respond(decoder, type)
      case .metadataRespondApplication(let str):
        result = FLAC__stream_decoder_set_metadata_respond_application(decoder, str)
      case .metadataRespondAll:
        result = FLAC__stream_decoder_set_metadata_respond_all(decoder)
      case .metadataIgnore(let type):
        result = FLAC__stream_decoder_set_metadata_ignore(decoder, type)
      case .metadataIgnoreApplication(let str):
        result = FLAC__stream_decoder_set_metadata_ignore_application(decoder, str)
      case .metadataIgnoreAll:
        result = FLAC__stream_decoder_set_metadata_ignore_all(decoder)
      }

      assert(result.cBool, "Only fail when the decoder is already initialized.")
    }

    let clientData = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
    let initStatus: FLAC__StreamDecoderInitStatus

    switch input {
    case .file(let filename):
      initStatus = FLAC__stream_decoder_init_file(decoder, filename, writeCallback, metadataCallback, errorCallback, clientData)
    case .cfile(let file):
      initStatus = FLAC__stream_decoder_init_FILE(decoder, file, writeCallback, metadataCallback, errorCallback, clientData)
    case .oggFile(let filename):
      initStatus = FLAC__stream_decoder_init_ogg_file(decoder, filename, writeCallback, metadataCallback, errorCallback, clientData)
    case .oggCFile(let file):
      initStatus = FLAC__stream_decoder_init_ogg_FILE(decoder, file, writeCallback, metadataCallback, errorCallback, clientData)
    case .stream:
      initStatus = FLAC__stream_decoder_init_stream(decoder, readCallback, seekCallback, tellCallback, lengthCallback, eofCallback, writeCallback, metadataCallback, errorCallback, clientData)
    case .oggStream:
      initStatus = FLAC__stream_decoder_init_ogg_stream(decoder, readCallback, seekCallback, tellCallback, lengthCallback, eofCallback, writeCallback, metadataCallback, errorCallback, clientData)
    }

    try preconditionOrThrow(initStatus == FLAC__STREAM_DECODER_INIT_STATUS_OK,
                            FlacDecoderInitError(initStatus))
  }

  deinit {
    FLAC__stream_decoder_delete(decoder)
  }
}

extension FlacDecoder {
  public enum DecoderOption {
    case oggSerialNumber(Int)
    case md5CheckingEnabled
    case metadataRespond(FLAC__MetadataType)
    case metadataRespondApplication(String)
    case metadataRespondAll
    case metadataIgnore(FLAC__MetadataType)
    case metadataIgnoreApplication(String)
    case metadataIgnoreAll
  }
}

public enum FlacDecoderProcessError: Error {
  case md5Mismatch
  case failedInState(FlacDecoderState)
  case seekFailed
}

// MARK: Decoder Processing
public extension FlacDecoder {

  func finish() throws {
    let ok = FLAC__stream_decoder_finish(decoder).cBool
    try preconditionOrThrow(ok, FlacDecoderProcessError.md5Mismatch)
  }

  func flush() throws {
    let ok = FLAC__stream_decoder_flush(decoder).cBool
    try preconditionOrThrow(ok, FlacDecoderProcessError.failedInState(state))
  }

  func reset() throws {
    let ok = FLAC__stream_decoder_reset(decoder).cBool
    try preconditionOrThrow(ok, FlacDecoderProcessError.failedInState(state))
  }

  func processSingle() throws {
    let ok = FLAC__stream_decoder_process_single(decoder).cBool
    try preconditionOrThrow(ok, FlacDecoderProcessError.failedInState(state))
  }

  func processUntilEndOfMetadata() throws {
    let ok = FLAC__stream_decoder_process_until_end_of_metadata(decoder).cBool
    try preconditionOrThrow(ok, FlacDecoderProcessError.failedInState(state))
  }

  func processUntilEndOfStream() throws {
    let ok = FLAC__stream_decoder_process_until_end_of_stream(decoder).cBool
    try preconditionOrThrow(ok, FlacDecoderProcessError.failedInState(state))
  }

  func skipSingleFrame() throws {
    let ok = FLAC__stream_decoder_skip_single_frame(decoder).cBool
    try preconditionOrThrow(ok, FlacDecoderProcessError.failedInState(state))
  }

  func seek(toAbsoluteSample: UInt64) -> Bool {
    FLAC__stream_decoder_seek_absolute(decoder, toAbsoluteSample).cBool
  }
}

// MARK: Decoder Properties
public extension FlacDecoder {

  var state: FlacDecoderState {
    .init(FLAC__stream_decoder_get_state(decoder))
  }

  var stateString: String {
    String(cString: FLAC__stream_decoder_get_resolved_state_string(decoder))
  }

  var md5Checking: Bool {
    FLAC__stream_decoder_get_md5_checking(decoder).cBool
  }

  var totalSamples: UInt64 {
    FLAC__stream_decoder_get_total_samples(decoder)
  }

  var channels: UInt32 {
    FLAC__stream_decoder_get_channels(decoder)
  }

  var channelAssignment: FLAC__ChannelAssignment {
    FLAC__stream_decoder_get_channel_assignment(decoder)
  }

  var bitsPerSample: UInt32 {
    FLAC__stream_decoder_get_bits_per_sample(decoder)
  }

  var sampleRate: UInt32 {
    FLAC__stream_decoder_get_sample_rate(decoder)
  }

  var blocksize: UInt32 {
    FLAC__stream_decoder_get_blocksize(decoder)
  }

  var decodePosition: UInt64? {
    var position = 0 as UInt64
    if FLAC__stream_decoder_get_decode_position(decoder, &position).cBool {
      return position
    }
    return nil
  }
}
