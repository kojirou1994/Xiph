import Foundation
import FLAC
import Precondition

extension FLAC__StreamDecoderInitStatus: Error {}
extension FLAC__StreamDecoderState: Error {}

// MARK: Base Delegate
public protocol FlacDecoderDelegate {
  mutating func didDecodeFrame(_ frame: UnsafePointer<FLAC__Frame>, buffers: UnsafePointer<UnsafePointer<Int32>?>?, decoder: FlacDecoder) -> FLAC__StreamDecoderWriteStatus
  mutating func didDecodeMetadata(_ metadata: FlacStreamMetadata, decoder: FlacDecoder)
  mutating func didOccurError(status: FLAC__StreamDecoderErrorStatus, decoder: FlacDecoder)
}

fileprivate func writeCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, frame: UnsafePointer<FLAC__Frame>?, buffers: UnsafePointer<UnsafePointer<FLAC__int32>?>?, client: UnsafeMutableRawPointer?) -> FLAC__StreamDecoderWriteStatus {
  let swiftDecoder = unsafeBitCast(client.unsafelyUnwrapped, to: FlacDecoder.self)
  return swiftDecoder.delegate?.didDecodeFrame(frame.unsafelyUnwrapped, buffers: buffers, decoder: swiftDecoder) ?? FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE
}

fileprivate func metadataCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, metadata: UnsafePointer<FLAC__StreamMetadata>?, client: UnsafeMutableRawPointer?) {
  let swiftDecoder = unsafeBitCast(client.unsafelyUnwrapped, to: FlacDecoder.self)
  swiftDecoder.delegate?.didDecodeMetadata(.autoCast(.init(mutating: metadata.unsafelyUnwrapped), owner: swiftDecoder), decoder: swiftDecoder)
}

fileprivate func errorCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, status: FLAC__StreamDecoderErrorStatus, client: UnsafeMutableRawPointer?)  {
  let swiftDecoder = unsafeBitCast(client.unsafelyUnwrapped, to: FlacDecoder.self)
  swiftDecoder.delegate?.didOccurError(status: status, decoder: swiftDecoder)
}

// MARK: Stream Delegate
public protocol FlacDecoderStreamDelegate {
  mutating func readInto(buffer: UnsafeMutablePointer<FLAC__byte>, bytesCount: UnsafeMutablePointer<Int>, decoder: FlacDecoder) -> FLAC__StreamDecoderReadStatus
  mutating func seekTo(absoluteByteOffset: UInt64, decoder: FlacDecoder) -> FLAC__StreamDecoderSeekStatus
  mutating func get(currentAbsoluteByteOffset: UnsafeMutablePointer<UInt64>, decoder: FlacDecoder) -> FLAC__StreamDecoderTellStatus
  mutating func get(totalStreamLength: UnsafeMutablePointer<UInt64>, decoder: FlacDecoder) -> FLAC__StreamDecoderLengthStatus
  mutating func isEndOfFile(decoder: FlacDecoder) -> Bool
}

fileprivate func readCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, buffer: UnsafeMutablePointer<FLAC__byte>?, bytes: UnsafeMutablePointer<Int>?, client: UnsafeMutableRawPointer?) -> FLAC__StreamDecoderReadStatus {
  let swiftDecoder = unsafeBitCast(client.unsafelyUnwrapped, to: FlacDecoder.self)
  return swiftDecoder.input.withUnsafeMutableStreamDelegate { provider in
    provider.readInto(buffer: buffer.unsafelyUnwrapped, bytesCount: bytes.unsafelyUnwrapped, decoder: swiftDecoder)
  }
}

fileprivate func seekCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, absolute_byte_offset: UInt64, client: UnsafeMutableRawPointer?) -> FLAC__StreamDecoderSeekStatus {
  let swiftDecoder = unsafeBitCast(client.unsafelyUnwrapped, to: FlacDecoder.self)
  return swiftDecoder.input.withUnsafeMutableStreamDelegate { provider in
    provider.seekTo(absoluteByteOffset: absolute_byte_offset, decoder: swiftDecoder)
  }
}

fileprivate func tellCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, absolute_byte_offset: UnsafeMutablePointer<FLAC__uint64>?, client: UnsafeMutableRawPointer?) -> FLAC__StreamDecoderTellStatus {
  let swiftDecoder = unsafeBitCast(client.unsafelyUnwrapped, to: FlacDecoder.self)
  return swiftDecoder.input.withUnsafeMutableStreamDelegate { provider in
    provider.get(currentAbsoluteByteOffset: absolute_byte_offset.unsafelyUnwrapped, decoder: swiftDecoder)
  }
}

fileprivate func lengthCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, streamLength: UnsafeMutablePointer<FLAC__uint64>?, client: UnsafeMutableRawPointer?) -> FLAC__StreamDecoderLengthStatus {
  let swiftDecoder = unsafeBitCast(client.unsafelyUnwrapped, to: FlacDecoder.self)
  return swiftDecoder.input.withUnsafeMutableStreamDelegate { provider in
    provider.get(totalStreamLength: streamLength.unsafelyUnwrapped, decoder: swiftDecoder)
  }
}

fileprivate func eofCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, client: UnsafeMutableRawPointer?) -> FLAC__bool {
  let swiftDecoder = unsafeBitCast(client.unsafelyUnwrapped, to: FlacDecoder.self)
  return swiftDecoder.input.withUnsafeMutableStreamDelegate { provider in
    provider.isEndOfFile(decoder: swiftDecoder).flacBool
  }
}

public final class FlacDecoder {

  private let decoder: UnsafeMutablePointer<FLAC__StreamDecoder>

  public fileprivate(set) var input: FlacInput

  fileprivate var delegate: FlacDecoderDelegate?

  ///
  /// - Parameters:
  ///   - input: input enum
  ///   - delegate: callback delegate
  /// - Throws: FLAC__StreamDecoderInitStatus
  public init(input: FlacInput, delegate: FlacDecoderDelegate?, options: [DecoderOption]) throws {
    decoder = try FLAC__stream_decoder_new()
      .unwrap(FLAC__STREAM_DECODER_INIT_STATUS_MEMORY_ALLOCATION_ERROR)
    self.delegate = delegate
    self.input = input

    if input.isOgg {
      checkOggFlacIsSupported()
    }

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
        precondition(str.utf8.count == 4)
        result = FLAC__stream_decoder_set_metadata_respond_application(decoder, str)
      case .metadataRespondAll:
        result = FLAC__stream_decoder_set_metadata_respond_all(decoder)
      case .metadataIgnore(let type):
        result = FLAC__stream_decoder_set_metadata_ignore(decoder, type)
      case .metadataIgnoreApplication(let str):
        precondition(str.utf8.count == 4)
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
      checkOggFlacIsSupported()
      initStatus = FLAC__stream_decoder_init_ogg_file(decoder, filename, writeCallback, metadataCallback, errorCallback, clientData)
    case .oggCFile(let file):
      checkOggFlacIsSupported()
      initStatus = FLAC__stream_decoder_init_ogg_FILE(decoder, file, writeCallback, metadataCallback, errorCallback, clientData)
    case .stream:
      initStatus = FLAC__stream_decoder_init_stream(decoder, readCallback, seekCallback, tellCallback, lengthCallback, eofCallback, writeCallback, metadataCallback, errorCallback, clientData)
    case .oggStream:
      checkOggFlacIsSupported()
      initStatus = FLAC__stream_decoder_init_ogg_stream(decoder, readCallback, seekCallback, tellCallback, lengthCallback, eofCallback, writeCallback, metadataCallback, errorCallback, clientData)
    }

    try preconditionOrThrow(initStatus == FLAC__STREAM_DECODER_INIT_STATUS_OK,
                            initStatus)
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
  case failedInState(FLAC__StreamDecoderState)
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

  var state: FLAC__StreamDecoderState {
    FLAC__stream_decoder_get_state(decoder)
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
