import FLAC
import Precondition
import CUtility

extension Flac {
  public struct Encoder: ~Copyable {

    @usableFromInline
    let encoder: UnsafeMutablePointer<FLAC__StreamEncoder>

    @usableFromInline
    var delegate: AnyObject?

    public init() throws {
      encoder = try FLAC__stream_encoder_new().unwrap()
    }

    deinit {
      FLAC__stream_encoder_delete(encoder)
    }
  }
}

public extension Flac.Encoder {
  private mutating func initilize(delegate: AnyObject?, body: (UnsafeMutablePointer<FLAC__StreamEncoder>, UnsafeMutableRawPointer?) -> OpenStatus) -> OpenStatus {
    assert(state == .uninitialized)
    assert(delegate == nil, "why delegate not released?")

    let client_data: UnsafeMutableRawPointer?

    if let delegate {
      client_data = Unmanaged.passUnretained(delegate).toOpaque()
    } else {
      client_data = nil
    }
    let initStatus = body(encoder, client_data)

    if initStatus == .ok {
      self.delegate = delegate
    }
    return initStatus
  }

  private mutating func initilize(callback: ProgressCallback?, body: (UnsafeMutablePointer<FLAC__StreamEncoder>, FLAC__StreamEncoderProgressCallback?, UnsafeMutableRawPointer?) -> OpenStatus) -> OpenStatus {

    let progress_callback: FLAC__StreamEncoderProgressCallback?
    let cb: Callback?
    if let callback {
      cb = .init(callback)
      progress_callback = progressCallback
    } else {
      cb = nil
      progress_callback = nil
    }
    return initilize(delegate: cb) { encoder, client_data in
      body(encoder, progress_callback, client_data)
    }
  }

  mutating func open(path: UnsafePointer<CChar>?, isOgg: Bool, callback: ProgressCallback?) -> OpenStatus {
    initilize(callback: callback) { encoder, progress_callback, client_data in
      if isOgg {
        FLAC__stream_encoder_init_ogg_file(encoder, path, progress_callback, client_data)
      } else {
        FLAC__stream_encoder_init_file(encoder, path, progress_callback, client_data)
      }
    }
  }

  mutating func open(file: UnsafeMutablePointer<FILE>, isOgg: Bool, callback: ProgressCallback?) -> OpenStatus {
    initilize(callback: callback) { encoder, progress_callback, client_data in
      if isOgg {
        FLAC__stream_encoder_init_ogg_FILE(encoder, file, progress_callback, client_data)
      } else {
        FLAC__stream_encoder_init_FILE(encoder, file, progress_callback, client_data)
      }
    }
  }

  mutating func open(stream: StreamInput, isOgg: Bool) -> OpenStatus {
    if isOgg {
      if stream.seek != nil {
        assert(stream.read != nil, "read must not be NULL if seek is non-NULL since they are both needed to be able to write data back to the Ogg")
      }
    }

    return initilize(delegate: stream) { encoder, clientData in
      if isOgg {
        FLAC__stream_encoder_init_ogg_stream(encoder, readCallback, writeCallback, seekCallback, tellCallback, metadataCallback, clientData)
      } else {
        FLAC__stream_encoder_init_stream(encoder, writeCallback, seekCallback, tellCallback, metadataCallback, clientData)
      }
    }
  }

  typealias ProgressCallback = (_ bytesWritten: UInt64, _ samplesWritten: UInt64, _ framesWritten: UInt32, _ totalFramesEstimate: UInt32) -> Void
  internal final class Callback {
    internal init(_ cb: @escaping ProgressCallback) {
      self.didWriteOneFrame = cb
    }
    let didWriteOneFrame: ProgressCallback
  }

  typealias ReadCallback = (_ buffer: UnsafeMutablePointer<FLAC__byte>?, _ bytes: UnsafeMutablePointer<Int>?) -> ReadStatus
  typealias WriteCallback = (_ buffer: UnsafePointer<UInt8>, _ bytes: Int, _ samples: UInt32, _ currentFrame: UInt32) -> WriteStatus
  typealias SeekCallback = (_ absoluteByteOffset: UInt64) -> SeekStatus
  typealias TellCallback = (_ currentAbsoluteByteOffset: UnsafeMutablePointer<UInt64>) -> TellStatus
  typealias MetadataCallback = (_ metadata: borrowing Flac.StreamMetadata) -> Void

  final class StreamInput {
    let read: ReadCallback?
    let write: WriteCallback
    let seek: SeekCallback?
    let tell: TellCallback?
    let metadata: MetadataCallback?

    public init(read: ReadCallback?, write: @escaping WriteCallback, seeking: (seek: SeekCallback, tell: TellCallback)?, metadata: MetadataCallback?) {
      self.read = read
      self.write = write
      self.seek = seeking?.seek
      self.tell = seeking?.tell
      self.metadata = metadata
    }
  }
}

// MARK: Callbacks
fileprivate func readCallback(encoder: UnsafePointer<FLAC__StreamEncoder>!, buffer: UnsafeMutablePointer<FLAC__byte>!, bytes: UnsafeMutablePointer<Int>!, client: UnsafeMutableRawPointer!) -> FLAC__StreamEncoderReadStatus {
  let delegate = Unmanaged<Flac.Encoder.StreamInput>.fromOpaque(client).takeUnretainedValue()
  return delegate.read!(buffer, bytes)
}

fileprivate func writeCallback(encoder: UnsafePointer<FLAC__StreamEncoder>!, buffer: UnsafePointer<FLAC__byte>?, bytes: Int, samples: UInt32, currentFrame: UInt32, client: UnsafeMutableRawPointer!) -> FLAC__StreamEncoderWriteStatus {
  let delegate = Unmanaged<Flac.Encoder.StreamInput>.fromOpaque(client).takeUnretainedValue()
  return delegate.write(buffer.unsafelyUnwrapped, bytes, samples, currentFrame)
}

fileprivate func seekCallback(encoder: UnsafePointer<FLAC__StreamEncoder>!, absoluteByteOffset: FLAC__uint64, client: UnsafeMutableRawPointer!) -> FLAC__StreamEncoderSeekStatus {
  let delegate = Unmanaged<Flac.Encoder.StreamInput>.fromOpaque(client).takeUnretainedValue()
  return delegate.seek!(absoluteByteOffset)
}

fileprivate func tellCallback(encoder: UnsafePointer<FLAC__StreamEncoder>!, absoluteByteOffset: UnsafeMutablePointer<FLAC__uint64>?, client: UnsafeMutableRawPointer!) -> FLAC__StreamEncoderTellStatus {
  let delegate = Unmanaged<Flac.Encoder.StreamInput>.fromOpaque(client).takeUnretainedValue()
  return delegate.tell!(absoluteByteOffset.unsafelyUnwrapped)
}

fileprivate func metadataCallback(encoder: UnsafePointer<FLAC__StreamEncoder>!, metadata: UnsafePointer<FLAC__StreamMetadata>!, client: UnsafeMutableRawPointer!) {
  let meta = Flac.StreamMetadata(.init(mutating: metadata))
  let delegate = Unmanaged<Flac.Encoder.StreamInput>.fromOpaque(client).takeUnretainedValue()
  delegate.metadata!(meta)
  _ = meta.take()
}

fileprivate func progressCallback(encoder: UnsafePointer<FLAC__StreamEncoder>!, bytesWritten: FLAC__uint64, samplesWritten: FLAC__uint64, framesWritten: UInt32, totalFramesEstimate: UInt32, client: UnsafeMutableRawPointer!)  {
  let cb = Unmanaged<Flac.Encoder.Callback>.fromOpaque(client).takeUnretainedValue()
//  let encoder = Encoder(.init(mutating: encoder))

  (cb.didWriteOneFrame)(bytesWritten, samplesWritten, framesWritten, totalFramesEstimate)//, encoder)

//  encoder.take()
}

// MARK: Encoder Processing
public extension Flac.Encoder {

  mutating func finish() -> Bool {
    let v = FLAC__stream_encoder_finish(encoder).cBool
    delegate = nil
    return v
  }

  func process(buffer: UnsafePointer<UnsafePointer<Int32>?>, samples: UInt32) -> Bool {
    FLAC__stream_encoder_process(encoder, buffer, samples).cBool
  }

  func processInterleaved(buffer: UnsafePointer<Int32>, samples: UInt32) -> Bool {
    FLAC__stream_encoder_process_interleaved(encoder, buffer, samples).cBool
  }

}

// MARK: Properties
public extension Flac.Encoder {

  typealias State = FLAC__StreamEncoderState

  typealias OpenStatus = FLAC__StreamEncoderInitStatus
  typealias ReadStatus = FLAC__StreamEncoderReadStatus
  typealias WriteStatus = FLAC__StreamEncoderWriteStatus
  typealias SeekStatus = FLAC__StreamEncoderSeekStatus
  typealias TellStatus = FLAC__StreamEncoderTellStatus

  private func safeSet(_ body: @autoclosure () -> FLAC__bool) {
    assert(state == .uninitialized, "the encoder is already initialized")
    let success = body().cBool
    assert(success)
  }

  var state: State {
    FLAC__stream_encoder_get_state(encoder)
  }

  var stateString: StaticCString {
    .init(cString: FLAC__stream_encoder_get_resolved_state_string(encoder))
  }

  var verifyDecoderState: Flac.Decoder.State {
    FLAC__stream_encoder_get_verify_decoder_state(encoder)
  }

  var channels: UInt32 {
    get { FLAC__stream_encoder_get_channels(encoder) }
    set { safeSet(FLAC__stream_encoder_set_channels(encoder, newValue)) }
  }

  var bitsPerSample: UInt32 {
    get { FLAC__stream_encoder_get_bits_per_sample(encoder) }
    set { safeSet(FLAC__stream_encoder_set_bits_per_sample(encoder, newValue)) }
  }

  var sampleRate: UInt32 {
    get { FLAC__stream_encoder_get_sample_rate(encoder) }
    set { safeSet(FLAC__stream_encoder_set_sample_rate(encoder, newValue)) }
  }

  var verify: Bool {
    get { FLAC__stream_encoder_get_verify(encoder).cBool }
    set { safeSet(FLAC__stream_encoder_set_verify(encoder, .init(cBool: newValue))) }
  }

  var blockSize: UInt32 {
    get { FLAC__stream_encoder_get_bits_per_sample(encoder) }
    set { safeSet(FLAC__stream_encoder_set_bits_per_sample(encoder, newValue)) }
  }

  var streamableSubset: Bool {
    get { FLAC__stream_encoder_get_streamable_subset(encoder).cBool }
    set { safeSet(FLAC__stream_encoder_set_streamable_subset(encoder, .init(cBool: newValue))) }
  }

  var doMidSideStereo: Bool {
    get { FLAC__stream_encoder_get_do_mid_side_stereo(encoder).cBool }
    set { safeSet(FLAC__stream_encoder_set_do_mid_side_stereo(encoder, .init(cBool: newValue))) }
  }

  var looseMidSideStereo: Bool {
    get { FLAC__stream_encoder_get_loose_mid_side_stereo(encoder).cBool }
    set { safeSet(FLAC__stream_encoder_set_loose_mid_side_stereo(encoder, .init(cBool: newValue))) }
  }

  var maxLpcOrder: UInt32 {
    get { FLAC__stream_encoder_get_max_lpc_order(encoder) }
    set { safeSet(FLAC__stream_encoder_set_max_lpc_order(encoder, newValue)) }
  }

  var qlpCoeffPrecision: UInt32 {
    get { FLAC__stream_encoder_get_qlp_coeff_precision(encoder) }
    set { safeSet(FLAC__stream_encoder_set_qlp_coeff_precision(encoder, newValue)) }
  }

  var doQlpCoeffPrecSearch: Bool {
    get { FLAC__stream_encoder_get_do_qlp_coeff_prec_search(encoder).cBool }
    set { safeSet(FLAC__stream_encoder_set_do_qlp_coeff_prec_search(encoder, .init(cBool: newValue))) }
  }

  var doEscapeCoding: Bool {
    get { FLAC__stream_encoder_get_do_escape_coding(encoder).cBool }
    @available(*, deprecated, message: "Deprecated. Setting this value has no effect.")
    set { safeSet(FLAC__stream_encoder_set_do_escape_coding(encoder, .init(cBool: newValue))) }
  }

  var doExhaustiveModelSearch: Bool {
    get { FLAC__stream_encoder_get_do_exhaustive_model_search(encoder).cBool }
    set { safeSet(FLAC__stream_encoder_set_do_exhaustive_model_search(encoder, .init(cBool: newValue))) }
  }

  var minResidualPartitionOrder: UInt32 {
    get { FLAC__stream_encoder_get_min_residual_partition_order(encoder) }
    set { safeSet(FLAC__stream_encoder_set_min_residual_partition_order(encoder, newValue)) }
  }

  var maxResidualPartitionOrder: UInt32 {
    get { FLAC__stream_encoder_get_max_residual_partition_order(encoder) }
    set { safeSet(FLAC__stream_encoder_set_max_residual_partition_order(encoder, newValue)) }
  }

  var riceParameterSearchDist: UInt32 {
    get { FLAC__stream_encoder_get_rice_parameter_search_dist(encoder) }
    @available(*, deprecated, message: "Deprecated. Setting this value has no effect.")
    set { safeSet(FLAC__stream_encoder_set_rice_parameter_search_dist(encoder, newValue)) }
  }

  var totalSamplesEstimate: UInt64 {
    get { FLAC__stream_encoder_get_total_samples_estimate(encoder) }
    set { safeSet(FLAC__stream_encoder_set_total_samples_estimate(encoder, newValue)) }
  }

//  var limitMinBitrate: Bool {
//    get { FLAC__stream_encoder_get_limit_min_bitrate(encoder).cBool }
//    set { safeSet(FLAC__stream_encoder_set_limit_min_bitrate(encoder, .init(cBool: newValue))) }

  func set(compressionLevel: UInt32) {
    safeSet(FLAC__stream_encoder_set_compression_level(encoder, compressionLevel))
  }

  func set(oggSerialNumber: Int) {
    safeSet(FLAC__stream_encoder_set_ogg_serial_number(encoder, oggSerialNumber))
  }

  func set(meta: inout MetadataBlocks) {
    FLAC__stream_encoder_set_metadata(encoder, &meta.ptrs, UInt32(meta.ptrs.count))
  }

  func set(apodization: UnsafePointer<CChar>) {
    safeSet(FLAC__stream_encoder_set_apodization(encoder, apodization))
  }

  func getVerifyDecoderErrorStats(absoluteSample: inout UInt64, frameNumber: inout UInt32, channel: inout UInt32, sample: inout UInt32, expected: inout Int32, got: inout Int32) {
    FLAC__stream_encoder_get_verify_decoder_error_stats(encoder, &absoluteSample, &frameNumber, &channel, &sample, &expected, &got)
  }

}

/// metadata array helper
public struct MetadataBlocks: ~Copyable {
  var ptrs: [UnsafeMutablePointer<FLAC__StreamMetadata>?] = []

  public init() {
  }

  public mutating func append(_ meta: consuming Flac.StreamMetadata) {
    ptrs.append(meta.take())
  }

  deinit {
    ptrs.forEach { FLAC__metadata_object_delete($0) }
  }
}

// MARK: Enum Values
public extension Flac.Encoder.State {
  static var ok: Self { FLAC__STREAM_ENCODER_OK }
  static var uninitialized: Self { FLAC__STREAM_ENCODER_UNINITIALIZED }
}

public extension Flac.Encoder.OpenStatus {
  static var ok: Self { FLAC__STREAM_ENCODER_INIT_STATUS_OK }
}

public extension Flac.Encoder.ReadStatus {
  static var `continue`: Self { FLAC__STREAM_ENCODER_READ_STATUS_CONTINUE }
  static var endOfStream: Self { FLAC__STREAM_ENCODER_READ_STATUS_END_OF_STREAM }
  static var abort: Self { FLAC__STREAM_ENCODER_READ_STATUS_ABORT }
  static var unsupported: Self { FLAC__STREAM_ENCODER_READ_STATUS_UNSUPPORTED }
}

public extension Flac.Encoder.WriteStatus {
  static var ok: Self { FLAC__STREAM_ENCODER_WRITE_STATUS_OK }
  static var fatalError: Self { FLAC__STREAM_ENCODER_WRITE_STATUS_FATAL_ERROR }
}

public extension Flac.Encoder.SeekStatus {
  static var ok: Self { FLAC__STREAM_ENCODER_SEEK_STATUS_OK }
  static var error: Self { FLAC__STREAM_ENCODER_SEEK_STATUS_ERROR }
  static var unsupported: Self { FLAC__STREAM_ENCODER_SEEK_STATUS_UNSUPPORTED }
}


public extension Flac.Encoder.TellStatus {
  static var ok: Self { FLAC__STREAM_ENCODER_TELL_STATUS_OK }
  static var error: Self { FLAC__STREAM_ENCODER_TELL_STATUS_ERROR }
  static var unsupported: Self { FLAC__STREAM_ENCODER_TELL_STATUS_UNSUPPORTED }
}
