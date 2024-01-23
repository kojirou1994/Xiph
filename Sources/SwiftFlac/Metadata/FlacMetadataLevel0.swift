import Precondition
import FLAC

extension Flac {
  public enum MetadataLevel0 {

    public static func getStreamInfo(filename: UnsafePointer<CChar>) throws -> Flac.StreamMetadata {
      let ptr = UnsafeMutablePointer<FLAC__StreamMetadata>.allocate(capacity: 1)
      try preconditionOrThrow(FLAC__metadata_get_streaminfo(filename, ptr).cBool)
      return .init(ptr)
    }

    public static func getTags(filename: UnsafePointer<CChar>) throws -> Flac.StreamMetadata {
      var ptr: UnsafeMutablePointer<FLAC__StreamMetadata>?
      try preconditionOrThrow(FLAC__metadata_get_tags(filename, &ptr).cBool)
      return .init(ptr.unsafelyUnwrapped)
    }

    public static func getCueSheet(filename: UnsafePointer<CChar>) throws -> Flac.StreamMetadata {
      var ptr: UnsafeMutablePointer<FLAC__StreamMetadata>?
      try preconditionOrThrow(FLAC__metadata_get_cuesheet(filename, &ptr).cBool)
      return .init(ptr.unsafelyUnwrapped)
    }

    public static func getPicture(
      filename: UnsafePointer<CChar>,
      ptype: Flac.StreamMetadata.Picture.PictureType?,
      mimeType: UnsafePointer<CChar>!,
      maxWidth: UInt32? = nil, maxHeight: UInt32? = nil,
      maxDepth: UInt32? = nil, maxColors: UInt32? = nil) throws -> Flac.StreamMetadata {
      var ptr: UnsafeMutablePointer<FLAC__StreamMetadata>?
      try preconditionOrThrow(
        FLAC__metadata_get_picture(
          filename, &ptr,
          ptype ?? FLAC__STREAM_METADATA_PICTURE_TYPE_UNDEFINED,
          mimeType, nil,
          maxWidth ?? UInt32.max, maxHeight ?? UInt32.max,
          maxDepth ?? UInt32.max, maxColors ?? UInt32.max).cBool)
      return .init(ptr.unsafelyUnwrapped)
    }
  }
}
