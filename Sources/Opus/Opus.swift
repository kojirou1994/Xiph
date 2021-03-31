import COpusfile
import KwiftExtension
import Foundation

// MARK: Opening and Closing
public final class OpusFile {

  let filePtr: OpaquePointer

  public init(path: String) throws {
    var error: CInt = 0
    let ptr = op_open_file(path, &error)
    self.filePtr = try ptr.unwrap(OpusError(error))
  }

  @available(*, unavailable)
  public init<D: ContiguousBytes>(data: D) throws {
    self.filePtr = try data.withUnsafeBytes { buffer in
      var error: CInt = 0
      let ptr = op_open_memory(buffer.baseAddress?.assumingMemoryBound(to: UInt8.self), buffer.count, &error)
      return try ptr.unwrap(OpusError(error))
    }
  }

  deinit {
    #if DEBUG
    //    print("Closing file")
    #endif
    op_free(filePtr)
  }
}

// MARK: Functions for obtaining information about streams
extension OpusFile {

  public var isSeekable: Bool {
    op_seekable(filePtr).cBool
  }

  public var linkCount: Int32 {
    op_link_count(filePtr)
  }

  public func serialNumber(at index: Int32) -> UInt32 {
    op_serialno(filePtr, index)
  }

  public func channelCount(at index: Int32) -> Int32 {
    op_channel_count(filePtr, index)
  }

  public func rawTotal(at index: Int32) -> Int64 {
    op_raw_total(filePtr, index)
  }

  /// Get the total PCM length (number of samples at 48 kHz) of the stream, or of an individual link in a (possibly-chained) Ogg Opus stream. Users looking for op_time_total() should use op_pcm_total() instead. Because timestamps in Opus are fixed at 48 kHz, there is no need for a separate function to convert this to seconds (and leaving it out avoids introducing floating point to the API, for those that wish to avoid it).
  /// - Parameter index: The index of the link whose PCM length should be computed. Use a negative number to get the PCM length of the entire stream.
  /// - Throws: #OP_EINVAL The stream is not seekable (so we can't know the length), index wasn't less than the total number of links in the stream, or the stream was only partially open.
  /// - Returns: The PCM length of the entire stream if index is negative, the PCM length of link index if it is non-negative, or a negative value on error.
  public func pcmTotal(at index: Int32) throws -> Int64 {
    op_pcm_total(filePtr, index)
  }

  /// Get the ID header information for the given link in a (possibly chained) Ogg Opus stream. This function may be called on partially-opened streams, but it will always return the ID header information of the Opus stream in the first link.
  /// - Parameter index: The index of the link whose ID header information should be retrieved. Use a negative number to get the ID header information of the current link. For an unseekable stream, _li is ignored, and the ID header information for the current link is always returned, if available.
  /// - Returns: The contents of the ID header for the given link.
  public func head(at index: Int32) -> OpusHead {
    .init(head: op_head(filePtr, index))
  }

  /// Get the comment header information for the given link in a (possibly chained) Ogg Opus stream. This function may be called on partially-opened streams, but it will always return the tags from the Opus stream in the first link.
  /// - Parameter index: The index of the link whose comment header information should be retrieved. Use a negative number to get the comment header information of the current link. For an unseekable stream, _li is ignored, and the comment header information for the current link is always returned, if available.
  /// - Throws: NilError if this is an unseekable stream that encountered an invalid link.
  /// - Returns: The contents of the comment header for the given link.
  public func tags(at index: Int32) throws -> OpusTags {
    .init(tags: try op_tags(filePtr, index).unwrap("Unseekable stream").pointee)
  }

  /// Retrieve the index of the current link. This is the link that produced the data most recently read by op_read_float() or its associated functions, or, after a seek, the link that the seek target landed in. Reading more data may advance the link index (even on the first read after a seek).
  /// - Throws: #OP_EINVAL The stream was only partially open.
  /// - Returns: The index of the current link on success, or a negative value on failure. For seekable streams, this is a number between 0 (inclusive) and the value returned by op_link_count() (exclusive). For unseekable streams, this value starts at 0 and increments by one each time a new link is encountered (even though op_link_count() always returns 1).
  public func currentLink() throws -> Int32 {
    op_current_link(filePtr)
  }

  /// Computes the bitrate of the stream, or of an individual link in a (possibly-chained) Ogg Opus stream. The stream must be seekable to compute the bitrate. For unseekable streams, use op_bitrate_instant() to get periodic estimates.
  /// - Parameter index: The index of the link whose bitrate should be computed. Use a negative number to get the bitrate of the whole stream.
  /// - Returns: The bitrate.
  /// - Throws: #OP_EINVAL The stream was only partially open, the stream was not seekable, or _li was larger than the number of links.
  public func bitrate(at index: Int32) throws -> Int32 {
    let value = op_bitrate(filePtr, index)
    try throwOpusError(value)
    return value
  }

  /// Compute the instantaneous bitrate, measured as the ratio of bits to playable samples decoded since a) the last call to op_bitrate_instant(), b) the last seek, or c) the start of playback, whichever was most recent. This will spike somewhat after a seek or at the start/end of a chain boundary, as pre-skip, pre-roll, and end-trimming causes samples to be decoded but not played.
  /// - Throws: #OP_FALSE No data has been decoded since any of the events described above. #OP_EINVAL The stream was only partially open.
  /// - Returns: The bitrate, in bits per second.
  public func instantaneousBitrate() throws -> Int32 {
    let value = op_bitrate_instant(filePtr)
    try throwOpusError(value)
    return value
  }

  /// Obtain the current value of the position indicator.
  /// - Throws: #OP_EINVAL The stream was only partially open.
  /// - Returns: The byte position that is currently being read from.
  public func rawOffset() throws -> Int64 {
    let offset = op_raw_tell(filePtr)
    try preconditionOrThrow(offset != OP_EINVAL, OpusError(OP_EINVAL))
    return offset
  }

  /// Obtain the PCM offset of the next sample to be read. If the stream is not properly timestamped, this might not increment by the proper amount between reads, or even return monotonically increasing values.
  /// - Throws: #OP_EINVAL The stream was only partially open.
  /// - Returns: The PCM offset of the next sample to be read.
  public func pcmOffset() throws -> Int64 {
    let offset = op_pcm_tell(filePtr)
    try preconditionOrThrow(offset != OP_EINVAL, OpusError(OP_EINVAL))
    return offset
  }
}

// MARK: Functions for seeking in Opus streams
extension OpusFile {
  /// Seek to a byte offset relative to the compressed data. This also scans packets to update the PCM cursor. It will cross a logical bitstream boundary, but only if it can't get any packets out of the tail of the link to which it seeks.
  /// - Parameter offset: The byte position to seek to. This must be between 0 and #op_raw_total(_of,-1) (inclusive).
  /// - Throws: OpusError on failure.
  public func seekRaw(to offset: Int64) throws {
    try throwOpusError(op_raw_seek(filePtr, offset))
  }

  /// Seek to the specified PCM offset, such that decoding will begin at exactly the requested position.
  /// - Parameter offset: The PCM offset to seek to. This is in samples at 48 kHz relative to the start of the stream.
  /// - Throws: OpusError on failure.
  public func seekPCM(to offset: Int64) throws {
    try throwOpusError(op_pcm_seek(filePtr, offset))
  }
}

// MARK: Functions for decoding audio data
extension OpusFile {

  public struct GainType: RawRepresentable {
    public let rawValue: Int32

    public init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    public static var header: Self { .init(rawValue: OP_HEADER_GAIN) }

    public static var album: Self { .init(rawValue: OP_ALBUM_GAIN) }

    public static var track: Self { .init(rawValue: OP_TRACK_GAIN) }

    public static var absolute: Self { .init(rawValue: OP_ABSOLUTE_GAIN) }
  }

  /// Sets the gain to be used for decoded output. By default, the gain in the header is applied with no additional offset. The total gain (including header gain and/or track gain, if applicable, and this offset), will be clamped to [-32768,32767]/256 dB. This is more than enough to saturate or underflow 16-bit PCM.
  /// - Parameters:
  ///   - gainOffset: The gain offset to apply, in 1/256ths of a dB.
  ///   - type: GainType
  /// - Throws: #OP_EINVAL The GainType was unrecognized.
  public func set(gainOffset: Int32, for gainType: GainType) throws {
    try throwOpusError(op_set_gain_offset(filePtr, gainType.rawValue, gainOffset))
  }

  /// Sets whether or not dithering is enabled for 16-bit decoding. By default, when libopusfile is compiled to use floating-point internally, calling op_read() or op_read_stereo() will first decode to float, and then convert to fixed-point using noise-shaping dithering. This flag can be used to disable that dithering. When the application uses op_read_float() or op_read_float_stereo(), or when the library has been compiled to decode directly to fixed point, this flag has no effect.
  /// - Parameter ditherEnabled: Bool value.
  public func set(ditherEnabled: Bool) {
    op_set_dither_enabled(filePtr, ditherEnabled ? 1 : 0)
  }

  public func read(to pcmBuffer: UnsafeMutableBufferPointer<Int16>) throws -> (sampleCount: Int32, index: Int32) {
    precondition(!pcmBuffer.isEmpty)
    var index: Int32 = 0
    let count = op_read(filePtr, pcmBuffer.baseAddress.unsafelyUnwrapped, Int32(pcmBuffer.count), &index)
    try throwOpusError(count)
    return (count, index)
  }

  public func read(to floatBuffer: UnsafeMutableBufferPointer<Float>) throws -> (sampleCount: Int32, index: Int32) {
    precondition(!floatBuffer.isEmpty)
    var index: Int32 = 0
    let count = op_read_float(
      filePtr, floatBuffer.baseAddress.unsafelyUnwrapped,
      .init(floatBuffer.count), &index)
    try throwOpusError(count)
    return (count, index)
  }

  public func readStereo(to pcmBuffer: UnsafeMutableBufferPointer<Int16>) throws -> Int32 {
    precondition(!pcmBuffer.isEmpty)
    let count = op_read_stereo(
      filePtr, pcmBuffer.baseAddress.unsafelyUnwrapped, .init(pcmBuffer.count))
    try throwOpusError(count)
    return count
  }

  public func readStereo(to floatBuffer: UnsafeMutableBufferPointer<Float>) throws -> Int32 {
    precondition(!floatBuffer.isEmpty)
    let count = op_read_float_stereo(
      filePtr, floatBuffer.baseAddress.unsafelyUnwrapped, .init(floatBuffer.count))
    try throwOpusError(count)
    return count
  }

  public class Decode {

  }

}

