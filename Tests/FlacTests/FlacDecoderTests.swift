import XCTest
import SwiftFlac

extension FileHandle {
  func write<T: UnsignedInteger & FixedWidthInteger>(_ number: T) throws {
    try withUnsafeBytes(of: number) { ptr in
      try kwiftWrite(contentsOf: ptr)
    }
  }

  func write(_ string: String) throws {
    try kwiftWrite(contentsOf: Array(string.utf8))
  }
}

fileprivate final class ExampleFlacEncoderDelegate: FlacEncoderDelegate {
  func didWriteOneFrame(bytesWritten: UInt64, samplesWritten: UInt64, framesWritten: UInt32, totalFramesEstimate: UInt32, encoder: FlacEncoder) {
    print(bytesWritten, samplesWritten, framesWritten, totalFramesEstimate)
  }
}
fileprivate final class ExampleFlacDecoderDelegate: FlacDecoderDelegate {

  internal init(filehandle: FileHandle) {
    self.filehandle = filehandle
  }

  var status: Status = .waitHead
  var streamInfo: FlacStreamMetadataStreamInfo?
  var encoder: FlacEncoder?

  enum Status {
    case waitHead
    case gotHeadAndWroteHead
//    case finished
  }

  let filehandle: FileHandle

  func didDecodeFrame(_ frame: UnsafePointer<FLAC__Frame>, buffers: UnsafePointer<UnsafePointer<Int32>?>?, decoder: FlacDecoder) -> FLAC__StreamDecoderWriteStatus {
//    print(#function)
    precondition(status == .gotHeadAndWroteHead)
    for i in 0..<Int(frame.pointee.header.blocksize) {
      try! filehandle.write(UInt16(truncatingIfNeeded: buffers![0]![i]))
      try! filehandle.write(UInt16(truncatingIfNeeded: buffers![1]![i]))
    }
    precondition(encoder!.process(buffer: buffers!, samples: frame.pointee.header.blocksize))
    return FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE
  }

  func didDecodeMetadata(_ metadata: FlacStreamMetadata, decoder: FlacDecoder) {
    print(#function)
    switch metadata.metatype {
    case FLAC__METADATA_TYPE_STREAMINFO:
      precondition(status == .waitHead)
      self.streamInfo = try! (metadata as! FlacStreamMetadataStreamInfo).clone()

      let channels = streamInfo!.channels
      let totalSamples = streamInfo!.total_samples
      let bitsPerSample = streamInfo!.bits_per_sample
      let sampleRate = streamInfo!.sample_rate
      let totalSize = UInt32(totalSamples) * channels * bitsPerSample / 8

      self.encoder = try! .init(output: .file("/Volumes/SAMSUNG_TF_64G/sound/re-enc.flac"), delegate: ExampleFlacEncoderDelegate(), options: .init(requiredOptions: .init(channels: channels, bitsPerSample: bitsPerSample, sampleRate: sampleRate, serialNumber: nil, totalSamplesEstimate: nil), optionalOptions: [.verifyEnabled, .compressionLevel(8)]))

      try! filehandle.write("RIFF")
      try! filehandle.write(totalSize+36)
      try! filehandle.write("WAVEfmt ")
      try! filehandle.write(16 as UInt32)
      try! filehandle.write(1 as UInt16)
      try! filehandle.write(UInt16(channels))
      try! filehandle.write(sampleRate*channels*bitsPerSample/8)
      try! filehandle.write(UInt16(channels*bitsPerSample/8))
      try! filehandle.write(UInt16(bitsPerSample))

      try! filehandle.write("data")
      try! filehandle.write(totalSize)

      status = .gotHeadAndWroteHead
    default:
      break
    }
  }

  func didOccurError(status: FLAC__StreamDecoderErrorStatus, decoder: FlacDecoder) {
    print(#function, status)
  }

}

final class FlacDecoderTests: XCTestCase {
  func testDecoder() throws {
    let path =
//    "/Volumes/SAMSUNG_TF_64G/sound/corrupt.flac"
      "/Volumes/SAMSUNG_TF_64G/sound/sample.flac"
    let outFile = URL(fileURLWithPath: "/Volumes/SAMSUNG_TF_64G/sound/out.wav")
    try? FileManager.default.removeItem(at: outFile)
    FileManager.default.createFile(atPath: outFile.path, contents: nil, attributes: nil)
    let fileHandle = try FileHandle(forWritingTo: outFile)
    let delegate = ExampleFlacDecoderDelegate(filehandle: fileHandle)
    let decoder = try FlacDecoder(input: .file(path), delegate: delegate, options: [.md5CheckingEnabled, .metadataRespondAll])
    try decoder.processUntilEndOfStream()
    delegate.encoder?.finish()
  }
}
