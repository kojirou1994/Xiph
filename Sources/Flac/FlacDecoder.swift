import Foundation
import CFlac
import Precondition

public enum FlacDecoderEror: Error {
  case allocateDecoder
  case initError(FlacDecoderInitFailedReason)
  case processFailed(state: FlacDecoderState)

  public enum FlacDecoderInitFailedReason {
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
        self = .unknown(v.rawValue)
      }

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
      self = .uninitialized
    default:
      // for future unknown error
      self = .unknown(state.rawValue)
    }
  }
}

public protocol FlacDecoderDelegate {
  func writeCallback(frame: UnsafePointer<FLAC__Frame>?, buffers: UnsafePointer<UnsafePointer<FLAC__int32>?>?) -> Bool
  func metadataCallback(metadata: UnsafePointer<FLAC__StreamMetadata>?)
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
  swiftDecoder.delegate?.metadataCallback(metadata: metadata)
}

fileprivate func errorCallback(decoder: UnsafePointer<FLAC__StreamDecoder>?, status: FLAC__StreamDecoderErrorStatus, client: UnsafeMutableRawPointer?)  {
  let swiftDecoder = unsafeBitCast(client!, to: FlacDecoder.self)
  swiftDecoder.delegate?.errorCallback(status: status)
}

public final class FlacDecoder {

  public let delegate: FlacDecoderDelegate?

  public enum Input {
    case file(String)
    case cfile(UnsafeMutablePointer<FILE>)
    case oggFile(String)
    case oggCFile(UnsafeMutablePointer<FILE>)
  }

  private let decoder: UnsafeMutablePointer<FLAC__StreamDecoder>

  public init(input: Input, delegate: FlacDecoderDelegate?) throws {
    decoder = try FLAC__stream_decoder_new()
      .unwrap(FlacDecoderEror.initError(.memoryAllocation))
    self.delegate = delegate

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
    }


    try preconditionOrThrow(initStatus == FLAC__STREAM_DECODER_INIT_STATUS_OK,
                            FlacDecoderEror.initError(.init(initStatus)))
  }

  public func processUntilEnd() throws {
    let ok = FLAC__stream_decoder_process_until_end_of_stream(decoder).boolValue
    try preconditionOrThrow(ok, FlacDecoderEror.processFailed(state: state))
  }

  public var state: FlacDecoderState {
    .init(FLAC__stream_decoder_get_state(decoder))
  }

  deinit {
    FLAC__stream_decoder_delete(decoder)
  }
}
