import COpusfile
import KwiftExtension
import Foundation

public final class OpusHead {
  //  @usableFromInline
  //  let needFree: Bool

  @usableFromInline
  let head: UnsafePointer<COpusfile.OpusHead>

  @usableFromInline
  internal init(head: UnsafePointer<COpusfile.OpusHead>) {
    //    self.needFree = false
    self.head = head
  }

  deinit {
    //    if needFree {
    //
    //    }
  }
}

extension OpusHead {
  public var version: Int32 {
    head.pointee.version
  }

  public var channelCount: Int32 {
    head.pointee.channel_count
  }

  public var preSkip: UInt32 {
    head.pointee.pre_skip
  }

  public var inputSampleRate: UInt32 {
    head.pointee.input_sample_rate
  }

  public var outputGain: Int32 {
    head.pointee.output_gain
  }

  public var mappingFamily: Int32 {
    head.pointee.mapping_family
  }

  public var streamCount: Int32 {
    head.pointee.stream_count
  }

  public var coupledCount: Int32 {
    head.pointee.coupled_count
  }

  public func withUnsafeMapping<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
    try withUnsafeBytes(of: head.pointee.mapping, body)
  }
}

extension OpusHead: CustomStringConvertible {
  public var description: String {
    """
    Pre-skip: \(preSkip)
    Playback gain: \(outputGain) dB
    Channels: \(channelCount)
    Original sample rate: \(inputSampleRate) Hz
    """
  }
}
