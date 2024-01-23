import FLAC
import Precondition
import CUtility

extension Flac {
  public struct Decoder: ~Copyable {
    @usableFromInline
    internal let decoder: UnsafeMutablePointer<FLAC__StreamDecoder>

    @usableFromInline
    internal var delegate: AnyObject?

    public init() throws {
      decoder = try FLAC__stream_decoder_new().unwrap()
    }

    deinit {
      FLAC__stream_decoder_delete(decoder)
    }
  }

}

public extension Flac.Decoder {
  mutating func open(path: UnsafePointer<CChar>?, isOgg: Bool, didDecodeFrame: @escaping WriteCallback, didDecodeMetadata: MetadataCallback?, didOccurError: @escaping ErrorCallback) -> OpenStatus {
    assert(state == .uninitialized)
    let callback = Callbacks(didDecodeFrame: didDecodeFrame, didDecodeMetadata: didDecodeMetadata, didOccurError: didOccurError)
    let clientData = Unmanaged.passUnretained(callback).toOpaque()
    let initStatus: OpenStatus
    let metadataCB: FLAC__StreamDecoderMetadataCallback? = didDecodeMetadata == nil ? nil : metadataCallback
    if isOgg {
      initStatus = FLAC__stream_decoder_init_ogg_file(decoder, path, writeCallback, metadataCB, errorCallback, clientData)
    } else {
      initStatus = FLAC__stream_decoder_init_file(decoder, path, writeCallback, metadataCB, errorCallback, clientData)
    }
    if initStatus == .ok {
      self.delegate = callback
    }
    return initStatus
  }

  mutating func open(file: consuming UnsafeMutablePointer<FILE>, isOgg: Bool, didDecodeFrame: @escaping WriteCallback, didDecodeMetadata: MetadataCallback?, didOccurError: @escaping ErrorCallback) -> OpenStatus {
    assert(state == .uninitialized)
    let callback = Callbacks(didDecodeFrame: didDecodeFrame, didDecodeMetadata: didDecodeMetadata, didOccurError: didOccurError)
    let clientData = Unmanaged.passUnretained(callback).toOpaque()
    let initStatus: OpenStatus
    let metadataCB: FLAC__StreamDecoderMetadataCallback? = didDecodeMetadata == nil ? nil : metadataCallback
    if isOgg {
      initStatus = FLAC__stream_decoder_init_ogg_FILE(decoder, file, writeCallback, metadataCB, errorCallback, clientData)
    } else {
      initStatus = FLAC__stream_decoder_init_FILE(decoder, file, writeCallback, metadataCB, errorCallback, clientData)
    }
    if initStatus == .ok {
      self.delegate = callback
    }
    return initStatus
  }

  mutating func open(stream: Callbacks, isOgg: Bool) -> OpenStatus {
    assert(state == .uninitialized)
    let clientData = Unmanaged.passUnretained(stream).toOpaque()
    let initStatus: OpenStatus
    let seekCB: FLAC__StreamDecoderSeekCallback? = stream.seek.map { _ in seekCallback }
    let tellCB: FLAC__StreamDecoderTellCallback? = stream.tell.map { _ in tellCallback }
    let lengthCB: FLAC__StreamDecoderLengthCallback? = stream.length.map { _ in lengthCallback }
    let eofCB: FLAC__StreamDecoderEofCallback? = stream.eof.map { _ in eofCallback }
    let metadataCB: FLAC__StreamDecoderMetadataCallback? = stream.didDecodeMetadata == nil ? nil : metadataCallback
    if isOgg {
      initStatus = FLAC__stream_decoder_init_ogg_stream(decoder, readCallback, seekCB, tellCB, lengthCB, eofCB, writeCallback, metadataCB, errorCallback, clientData)
    } else {
      initStatus = FLAC__stream_decoder_init_stream(decoder, readCallback, seekCB, tellCB, lengthCB, eofCB, writeCallback, metadataCB, errorCallback, clientData)
    }
    if initStatus == .ok {
      self.delegate = stream
    }
    return initStatus
  }

  typealias OpenStatus = FLAC__StreamDecoderInitStatus
  typealias ReadStatus = FLAC__StreamDecoderReadStatus
  typealias SeekStatus = FLAC__StreamDecoderSeekStatus
  typealias TellStatus = FLAC__StreamDecoderTellStatus
  typealias LengthStatus = FLAC__StreamDecoderLengthStatus
  typealias WriteStatus = FLAC__StreamDecoderWriteStatus
  typealias ErrorStatus = FLAC__StreamDecoderErrorStatus

  typealias WriteCallback = (_ frame: borrowing Flac.Frame, _ buffers: UnsafePointer<UnsafePointer<Int32>?>) -> WriteStatus
  typealias MetadataCallback = (_ metadata: borrowing Flac.StreamMetadata) -> Void
  typealias ErrorCallback = (_ status: FLAC__StreamDecoderErrorStatus) -> Void
  typealias ReadCallback = (_ buffer: UnsafeMutablePointer<UInt8>?, _ bytes: UnsafeMutablePointer<Int>?) -> ReadStatus
  typealias SeekCallback = (_ absoluteByteOffset: UInt64) -> SeekStatus
  typealias TellCallback = (_ currentAbsoluteByteOffset: UnsafeMutablePointer<UInt64>) -> TellStatus
  typealias LengthCallback = (_ streanLength: inout UInt64) -> LengthStatus
  typealias EOFCallback = () -> Bool

  final class Callbacks {
    // for file input
    init(didDecodeFrame: @escaping WriteCallback, didDecodeMetadata: MetadataCallback?, didOccurError: @escaping ErrorCallback) {
      self.didDecodeFrame = didDecodeFrame
      self.didDecodeMetadata = didDecodeMetadata
      self.didOccurError = didOccurError
      self.read = nil
      self.seek = nil
      self.tell = nil
      self.length = nil
      self.eof = nil
    }

    // for stream
    public init(didDecodeFrame: @escaping WriteCallback, didDecodeMetadata: MetadataCallback?, didOccurError: @escaping ErrorCallback, read: @escaping ReadCallback, seek: SeekCallback?, tell: TellCallback?, length: LengthCallback?, eof: EOFCallback?) {
      self.didDecodeFrame = didDecodeFrame
      self.didDecodeMetadata = didDecodeMetadata
      self.didOccurError = didOccurError
      self.read = read
      self.seek = seek
      self.tell = tell
      self.length = length
      self.eof = eof
    }

    let didDecodeFrame: WriteCallback
    let didDecodeMetadata: MetadataCallback?
    let didOccurError: ErrorCallback

    /// This pointer must not be NULL for stream INPUT
    let read: ReadCallback?
    let seek: SeekCallback?
    let tell: TellCallback?
    let length: LengthCallback?
    let eof: EOFCallback?

    deinit {
      #if DEBUG
      print(#function, "released")
      #endif
    }
  }

}

// MARK: Callbacks
fileprivate func writeCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, frame: UnsafePointer<FLAC__Frame>!, buffers: UnsafePointer<UnsafePointer<FLAC__int32>?>!, client: UnsafeMutableRawPointer!) -> FLAC__StreamDecoderWriteStatus {
  let delegate = Unmanaged<Flac.Decoder.Callbacks>.fromOpaque(client).takeUnretainedValue()
  return delegate.didDecodeFrame(.init(frame: frame), buffers)
}

fileprivate func metadataCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, metadata: UnsafePointer<FLAC__StreamMetadata>!, client: UnsafeMutableRawPointer!) {
  let meta = Flac.StreamMetadata(.init(mutating: metadata))
  let delegate = Unmanaged<Flac.Decoder.Callbacks>.fromOpaque(client).takeUnretainedValue()
  delegate.didDecodeMetadata!(meta)
  _ = meta.take()
}

fileprivate func errorCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, status: FLAC__StreamDecoderErrorStatus, client: UnsafeMutableRawPointer!)  {
  let delegate = Unmanaged<Flac.Decoder.Callbacks>.fromOpaque(client).takeUnretainedValue()
  delegate.didOccurError(status)
}

fileprivate func readCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, buffer: UnsafeMutablePointer<FLAC__byte>!, bytes: UnsafeMutablePointer<Int>!, client: UnsafeMutableRawPointer!) -> FLAC__StreamDecoderReadStatus {
  let delegate = Unmanaged<Flac.Decoder.Callbacks>.fromOpaque(client).takeUnretainedValue()
  return delegate.read!(buffer, bytes)
}

fileprivate func seekCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, absolute_byte_offset: UInt64, client: UnsafeMutableRawPointer!) -> FLAC__StreamDecoderSeekStatus {
  let delegate = Unmanaged<Flac.Decoder.Callbacks>.fromOpaque(client).takeUnretainedValue()
  return delegate.seek!(absolute_byte_offset)
}

fileprivate func tellCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, absolute_byte_offset: UnsafeMutablePointer<FLAC__uint64>!, client: UnsafeMutableRawPointer!) -> FLAC__StreamDecoderTellStatus {
  let delegate = Unmanaged<Flac.Decoder.Callbacks>.fromOpaque(client).takeUnretainedValue()
  return delegate.tell!(absolute_byte_offset)
}

fileprivate func lengthCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, streamLength: UnsafeMutablePointer<FLAC__uint64>!, client: UnsafeMutableRawPointer!) -> FLAC__StreamDecoderLengthStatus {
  let delegate = Unmanaged<Flac.Decoder.Callbacks>.fromOpaque(client).takeUnretainedValue()
  return delegate.length!(&streamLength.pointee)
}

fileprivate func eofCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, client: UnsafeMutableRawPointer!) -> FLAC__bool {
  let delegate = Unmanaged<Flac.Decoder.Callbacks>.fromOpaque(client).takeUnretainedValue()
  return .init(cBool: delegate.eof!())
}

// MARK: Decoder Processing
public extension Flac.Decoder {

  mutating func finish() -> Bool {
    let v = FLAC__stream_decoder_finish(decoder).cBool
    delegate = nil
    return v
  }

  func flush() -> Bool {
    FLAC__stream_decoder_flush(decoder).cBool
  }

  func reset() -> Bool {
    FLAC__stream_decoder_reset(decoder).cBool
  }

  func processSingle() -> Bool {
    FLAC__stream_decoder_process_single(decoder).cBool
  }

  func processUntilEndOfMetadata() -> Bool {
    FLAC__stream_decoder_process_until_end_of_metadata(decoder).cBool
  }

  func processUntilEndOfStream() -> Bool {
    FLAC__stream_decoder_process_until_end_of_stream(decoder).cBool
  }

  func skipSingleFrame() -> Bool {
    FLAC__stream_decoder_skip_single_frame(decoder).cBool
  }

  func seek(toAbsoluteSample: UInt64) -> Bool {
    FLAC__stream_decoder_seek_absolute(decoder, toAbsoluteSample).cBool
  }
}

// MARK: Properties
public extension Flac.Decoder {

  typealias State = FLAC__StreamDecoderState

  private func safeSet(_ body: @autoclosure () -> FLAC__bool) {
    assert(state == .uninitialized, "the decoder is already initialized")
    let success = body().cBool
    assert(success)
  }

  var state: State {
    FLAC__stream_decoder_get_state(decoder)
  }

  var stateString: StaticCString {
    .init(cString: FLAC__stream_decoder_get_resolved_state_string(decoder))
  }

  var md5Checking: Bool {
    get { FLAC__stream_decoder_get_md5_checking(decoder).cBool }
    set { safeSet(FLAC__stream_decoder_set_md5_checking(decoder, .init(cBool: newValue))) }
  }

  var totalSamples: UInt64 {
    FLAC__stream_decoder_get_total_samples(decoder)
  }

  var channels: UInt32 {
    FLAC__stream_decoder_get_channels(decoder)
  }

  var channelAssignment: Flac.ChannelAssignment {
    FLAC__stream_decoder_get_channel_assignment(decoder)
  }

  var bitsPerSample: UInt32 {
    FLAC__stream_decoder_get_bits_per_sample(decoder)
  }

  var sampleRate: UInt32 {
    FLAC__stream_decoder_get_sample_rate(decoder)
  }

  var blockSize: UInt32 {
    FLAC__stream_decoder_get_blocksize(decoder)
  }

  func get(decodePosition: inout UInt64) -> Bool {
    FLAC__stream_decoder_get_decode_position(decoder, &decodePosition).cBool
  }

  mutating func set(oggSerialNumber: Int) {
    safeSet(FLAC__stream_decoder_set_ogg_serial_number(decoder, oggSerialNumber))
  }

  mutating func respond(type: FLAC__MetadataType) {
    safeSet(FLAC__stream_decoder_set_metadata_respond(decoder, type))
  }

  mutating func respond(applicationID: [UInt8]) {
    safeSet(FLAC__stream_decoder_set_metadata_respond_application(decoder, applicationID))
  }

  mutating func respondAll() {
    safeSet(FLAC__stream_decoder_set_metadata_respond_all(decoder))
  }

  mutating func ignore(type: FLAC__MetadataType) {
    safeSet(FLAC__stream_decoder_set_metadata_ignore(decoder, type))
  }

  mutating func ignore(applicationID: [UInt8]) {
    safeSet(FLAC__stream_decoder_set_metadata_ignore_application(decoder, applicationID))
  }

  mutating func ignoreAll() {
    safeSet(FLAC__stream_decoder_set_metadata_ignore_all(decoder))
  }
}

// MARK: Enum Values
public extension Flac.Decoder.State {
  static var searchForMetadata: Self { FLAC__STREAM_DECODER_SEARCH_FOR_METADATA }
  static var uninitialized: Self { FLAC__STREAM_DECODER_UNINITIALIZED }
}

public extension Flac.Decoder.WriteStatus {
  /// The write was OK and decoding can continue.
  @_alwaysEmitIntoClient
  static var `continue`: Self { FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE }
  /// An unrecoverable error occurred.  The decoder will return from the process call.
  @_alwaysEmitIntoClient
  static var abort: Self { FLAC__STREAM_DECODER_WRITE_STATUS_ABORT }
}

public extension Flac.Decoder.ErrorStatus {
  /// An error in the stream caused the decoder to lose synchronization.
  @_alwaysEmitIntoClient
  static var lostSync: Self { FLAC__STREAM_DECODER_ERROR_STATUS_LOST_SYNC }
  /// The decoder encountered a corrupted frame header.
  @_alwaysEmitIntoClient
  static var badHeader: Self { FLAC__STREAM_DECODER_ERROR_STATUS_BAD_HEADER }
  /// The frame's data did not match the CRC in the footer.
  @_alwaysEmitIntoClient
  static var frameCrcMismatch: Self { FLAC__STREAM_DECODER_ERROR_STATUS_FRAME_CRC_MISMATCH }
  /// The decoder encountered reserved fields in use in the stream.
  @_alwaysEmitIntoClient
  static var unparseableStream: Self { FLAC__STREAM_DECODER_ERROR_STATUS_UNPARSEABLE_STREAM }
}

public extension Flac.Decoder.OpenStatus {
  static var ok: Self { FLAC__STREAM_DECODER_INIT_STATUS_OK }
}
