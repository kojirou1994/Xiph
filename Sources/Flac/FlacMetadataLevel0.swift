public enum FlacMetadataLevel0 {

    public static func getStreamInfo(filename: String) throws -> FlacStreamMetadata {
    let ptr = UnsafeMutablePointer<FLAC__StreamMetadata>.allocate(capacity: 1)
    try preconditionOrThrow(FLAC__metadata_get_streaminfo(filename, ptr).cBool)
    return .init(ptr)
  }

    public static func getTags(filename: String) throws -> FlacStreamMetadata {
    var ptr: UnsafeMutablePointer<FLAC__StreamMetadata>?
    try preconditionOrThrow(FLAC__metadata_get_tags(filename, &ptr).cBool)
    return .init(ptr.unsafelyUnwrapped)
  }

    public static func getCueSheet(filename: String) throws -> FlacStreamMetadata {
    var ptr: UnsafeMutablePointer<FLAC__StreamMetadata>?
    try preconditionOrThrow(FLAC__metadata_get_cuesheet(filename, &ptr).cBool)
    return .init(ptr.unsafelyUnwrapped)
  }

    public static func getPicture(
    filename: String,
    ptype: FLAC__StreamMetadata_Picture_Type?,
    mimeType: UnsafePointer<Int8>!,
    maxWidth: UInt32? = nil, maxHeight: UInt32? = nil,
    maxDepth: UInt32? = nil, maxColors: UInt32? = nil)
  throws -> FlacStreamMetadata {
    var ptr: UnsafeMutablePointer<FLAC__StreamMetadata>?
    try preconditionOrThrow(
      FLAC__metadata_get_picture(
        filename, &ptr,
        ptype ?? FLAC__StreamMetadata_Picture_Type(UInt32.max),
        mimeType, nil,
        maxWidth ?? UInt32.max, maxHeight ?? UInt32.max,
        maxDepth ?? UInt32.max, maxColors ?? UInt32.max).cBool)
    return .init(ptr.unsafelyUnwrapped)
  }
}
