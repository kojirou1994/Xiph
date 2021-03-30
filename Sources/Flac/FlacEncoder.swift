import Foundation
import CFlac
import Precondition

extension FLAC__StreamEncoderInitStatus: Error {}

// MARK: Base Callbacks
public protocol FlacEncoderDelegate {
  mutating func progressCallback(bytesWritten: UInt64, samplesWritten: UInt64, framesWritten: UInt32, totalFramesEstimate: UInt32)
}

fileprivate func progressCallback(encoder: UnsafePointer<FLAC__StreamEncoder>?, bytesWritten: FLAC__uint64, samplesWritten: FLAC__uint64, framesWritten: UInt32, totalFramesEstimate: UInt32, client: UnsafeMutableRawPointer?)  {
  let swiftEncoder = unsafeBitCast(client.unsafelyUnwrapped, to: FlacEncoder.self)
  swiftEncoder.delegate?.progressCallback(bytesWritten: bytesWritten, samplesWritten: samplesWritten, framesWritten: framesWritten, totalFramesEstimate: totalFramesEstimate)
}

// MARK: Stream Callbacks
public protocol FlacEncoderStreamDelegate {
  func writeCallback(buffer: UnsafePointer<FLAC__byte>?, bytes: Int, samples: UInt32, currentFrame: UInt32) -> FLAC__StreamEncoderWriteStatus
  func seekCallback(absoluteByteOffset: FLAC__uint64) -> FLAC__StreamEncoderSeekStatus
  func tellCallback(absoluteByteOffset: UnsafeMutablePointer<FLAC__uint64>?) -> FLAC__StreamEncoderTellStatus
  func metadataCallback(metadata: FlacStreamMetadata)
}

fileprivate func writeCallback(encoder: UnsafePointer<FLAC__StreamEncoder>?, buffer: UnsafePointer<FLAC__byte>?, bytes: Int, samples: UInt32, currentFrame: UInt32, client: UnsafeMutableRawPointer?) -> FLAC__StreamEncoderWriteStatus {
  let swiftEncoder = unsafeBitCast(client.unsafelyUnwrapped, to: FlacEncoder.self)
  switch swiftEncoder.output {
  case .stream(let delegate), .oggStream(let delegate):
    return delegate.writeCallback(buffer: buffer, bytes: bytes, samples: samples, currentFrame: currentFrame)
  default:
    fatalError()
  }
}

fileprivate func seekCallback(encoder: UnsafePointer<FLAC__StreamEncoder>?, absoluteByteOffset: FLAC__uint64, client: UnsafeMutableRawPointer?) -> FLAC__StreamEncoderSeekStatus {
  let swiftEncoder = unsafeBitCast(client.unsafelyUnwrapped, to: FlacEncoder.self)
  switch swiftEncoder.output {
  case .stream(let delegate), .oggStream(let delegate):
    return delegate.seekCallback(absoluteByteOffset: absoluteByteOffset)
  default:
    fatalError()
  }
}

fileprivate func tellCallback(encoder: UnsafePointer<FLAC__StreamEncoder>?, absoluteByteOffset: UnsafeMutablePointer<FLAC__uint64>?, client: UnsafeMutableRawPointer?) -> FLAC__StreamEncoderTellStatus {
  let swiftEncoder = unsafeBitCast(client.unsafelyUnwrapped, to: FlacEncoder.self)
  switch swiftEncoder.output {
  case .stream(let delegate), .oggStream(let delegate):
    return delegate.tellCallback(absoluteByteOffset: absoluteByteOffset)
  default:
    fatalError()
  }
}

fileprivate func metadataCallback(encoder: UnsafePointer<FLAC__StreamEncoder>?, metadata: UnsafePointer<FLAC__StreamMetadata>?, client: UnsafeMutableRawPointer?) {
  let swiftEncoder = unsafeBitCast(client.unsafelyUnwrapped, to: FlacEncoder.self)
  switch swiftEncoder.output {
  case .stream(let delegate), .oggStream(let delegate):
    return delegate.metadataCallback(metadata: .init(.init(mutating: metadata.unsafelyUnwrapped), owner: swiftEncoder))
  default:
    fatalError()
  }
}

public final class FlacEncoder {

  private let encoder: UnsafeMutablePointer<FLAC__StreamEncoder>

  public let output: Output
  public let options: Options

  fileprivate var delegate: FlacEncoderDelegate?

  public enum Output {
    case file(String)
    case cfile(UnsafeMutablePointer<FILE>)
    case oggFile(String)
    case oggCFile(UnsafeMutablePointer<FILE>)
    case stream(FlacEncoderStreamDelegate)
    case oggStream(FlacEncoderStreamDelegate)

    var isOgg: Bool {
      switch self {
      case .oggFile, .oggCFile, .oggStream:
        return true
      default:
        return false
      }
    }
  }

  public init(output: Output, delegate: FlacEncoderDelegate?, options: Options) throws {
    encoder = try FLAC__stream_encoder_new()
      .unwrap(FLAC__STREAM_ENCODER_INIT_STATUS_ENCODER_ERROR)
    self.delegate = delegate
    self.output = output
    self.options = options

    // set up options
    do {
      func check(_ result: FLAC__bool) {
        assert(result.cBool, "Only fail when the encoder is already initialized.")
      }
      // required
      check(FLAC__stream_encoder_set_channels(encoder, options.requiredOptions.channels))
      check(FLAC__stream_encoder_set_bits_per_sample(encoder, options.requiredOptions.bitsPerSample))
      check(FLAC__stream_encoder_set_sample_rate(encoder, options.requiredOptions.sampleRate))
      if output.isOgg {
        try check(FLAC__stream_encoder_set_ogg_serial_number(encoder, options.requiredOptions.serialNumber.unwrap("Ogg serial number must be set!")))
      }
      
      options.requiredOptions.totalSamplesEstimate
        .map { check(FLAC__stream_encoder_set_total_samples_estimate(encoder, $0)) }

      // optional
      options.optionalOptions.forEach { option in
        switch option {
        case .verifyEnabled:
          check(FLAC__stream_encoder_set_verify(encoder, true.flacBool))
        case .compressionLevel(let value):
          check(FLAC__stream_encoder_set_compression_level(encoder, value))
        case .metadatas(let metadatas):
          var metaPtrs: [UnsafeMutablePointer<FLAC__StreamMetadata>?] = metadatas.map(\.ptr)
          check(FLAC__stream_encoder_set_metadata(encoder, &metaPtrs, UInt32(metadatas.count)))
        }
      }
    }

    let clientData = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
    let initStatus: FLAC__StreamEncoderInitStatus

    switch output {
    case .file(let filename):
      initStatus = FLAC__stream_encoder_init_file(encoder, filename, progressCallback, clientData)
    case .cfile(let file):
      initStatus = FLAC__stream_encoder_init_FILE(encoder, file, progressCallback, clientData)
    case .oggFile(let filename):
      initStatus = FLAC__stream_encoder_init_ogg_file(encoder, filename, progressCallback, clientData)
    case .oggCFile(let file):
      initStatus = FLAC__stream_encoder_init_ogg_FILE(encoder, file, progressCallback, clientData)
    case .stream:
      initStatus = FLAC__stream_encoder_init_stream(encoder, writeCallback, seekCallback, tellCallback, metadataCallback, clientData)
    case .oggStream:
      initStatus = FLAC__stream_encoder_init_ogg_stream(encoder, nil, writeCallback, seekCallback, tellCallback, metadataCallback, clientData)
    }

    try preconditionOrThrow(initStatus == FLAC__STREAM_ENCODER_INIT_STATUS_OK,
                            initStatus)
  }

  deinit {
    FLAC__stream_encoder_delete(encoder)
  }
}

extension FlacEncoder {
  public struct Options {
    public init(requiredOptions: FlacEncoder.Options.RequiredOptions, optionalOptions: [FlacEncoder.Options.OptionalOption]) {
      self.requiredOptions = requiredOptions
      self.optionalOptions = optionalOptions
    }

    public struct RequiredOptions {
      public init(channels: UInt32, bitsPerSample: UInt32, sampleRate: UInt32, serialNumber: Int?, totalSamplesEstimate: UInt64?) {
        self.channels = channels
        self.bitsPerSample = bitsPerSample
        self.sampleRate = sampleRate
        self.serialNumber = serialNumber
        self.totalSamplesEstimate = totalSamplesEstimate
      }

      public let channels: UInt32
      public let bitsPerSample: UInt32
      public let sampleRate: UInt32
      public let serialNumber: Int? //if encoding to Ogg FLAC
      public let totalSamplesEstimate: UInt64?
    }
    public let requiredOptions: RequiredOptions
    public let optionalOptions: [OptionalOption]
    public enum OptionalOption {
      case verifyEnabled
//      case streamableSubsetDisabled
      case compressionLevel(UInt32)
      case metadatas([FlacStreamMetadata])
//      case blocksize(UInt32)
//      case doMidSideStereo
//      case looseMidSideStereo
//      case apodization(String)
//      case maxLpcOrder(UInt32)
//      case qlpCoeffPrecision(UInt32)
//      case doQlpCoeffPrecSearch
//      case doEscapeCoding
//      case doExhaustiveModelSearch
    }
    
  }
}

// MARK: Encoder Processing
public extension FlacEncoder {

  func finish() -> Bool {
    FLAC__stream_encoder_finish(encoder).cBool
  }

  func process(buffer: UnsafePointer<UnsafePointer<FLAC__int32>?>, samples: UInt32) -> Bool {
    FLAC__stream_encoder_process(encoder, buffer, samples).cBool
  }

  func processInterleaved(buffer: UnsafePointer<FLAC__int32>, samples: UInt32) -> Bool {
    FLAC__stream_encoder_process_interleaved(encoder, buffer, samples).cBool
  }

}

// MARK: Decoder Properties
public extension FlacEncoder {

  var state: FLAC__StreamEncoderState {
    FLAC__stream_encoder_get_state(encoder)
  }

  var stateString: String {
    String(cString: FLAC__stream_encoder_get_resolved_state_string(encoder))
  }

  var verifyDecoderState: FLAC__StreamDecoderState {
    FLAC__stream_encoder_get_verify_decoder_state(encoder)
  }

}
