import FLAC
import CUtility
import Precondition

extension Flac {
  public struct StreamMetadata: ~Copyable {

    public typealias MetadataType = FLAC__MetadataType

    let ptr: UnsafeMutablePointer<FLAC__StreamMetadata>

    init(_ ptr: UnsafeMutablePointer<FLAC__StreamMetadata>) {
      self.ptr = ptr
    }

    init(type: MetadataType) throws {
      ptr = try FLAC__metadata_object_new(type).unwrap()
    }

    deinit {
      FLAC__metadata_object_delete(ptr)
    }
  }
}

public extension Flac.StreamMetadata {
  var isLast: Bool {
    ptr.pointee.is_last.cBool
  }

  var length: UInt32 {
    ptr.pointee.length
  }

  var metatype: MetadataType {
    ptr.pointee.type
  }
}

public extension Flac.StreamMetadata {
  func clone() throws -> Self {
    Self(try FLAC__metadata_object_clone(ptr).unwrap())
  }

  func equals(to rhs: borrowing Self) -> Bool {
    FLAC__metadata_object_is_equal(self.ptr, rhs.ptr).cBool
  }

  internal consuming func take() -> UnsafeMutablePointer<FLAC__StreamMetadata> {
    let v = ptr
    discard self
    return v
  }
}

public extension Flac.StreamMetadata.MetadataType {
  static var streamInfo: Self { FLAC__METADATA_TYPE_STREAMINFO }
  static var padding: Self { FLAC__METADATA_TYPE_PADDING }
  static var application: Self { FLAC__METADATA_TYPE_APPLICATION }
  static var seektable: Self { FLAC__METADATA_TYPE_SEEKTABLE }
  static var vorbisComment: Self { FLAC__METADATA_TYPE_VORBIS_COMMENT }
  static var cuesheet: Self { FLAC__METADATA_TYPE_CUESHEET }
  static var picture: Self { FLAC__METADATA_TYPE_PICTURE }
}

// MARK: Sub Types
public extension Flac.StreamMetadata {

  typealias StreamInfo = FLAC__StreamMetadata_StreamInfo

  var streamInfo: StreamInfo {
    assert(metatype == .streamInfo)
    return ptr.pointee.data.stream_info
  }

  struct VorbisComment: ~Copyable {
    let ptr: UnsafeMutablePointer<FLAC__StreamMetadata>
  }

  struct Picture: ~Copyable {
    let ptr: UnsafeMutablePointer<FLAC__StreamMetadata>

    public typealias PictureType = FLAC__StreamMetadata_Picture_Type
  }

  struct Application: ~Copyable {
    let ptr: UnsafeMutablePointer<FLAC__StreamMetadata>
  }
}

extension Flac.StreamMetadata.VorbisComment.Entry { //}: ContiguousUTF8Bytes, CStringConvertible {
  public func withCString<Result>(_ body: (UnsafePointer<CChar>) throws -> Result) rethrows -> Result {
    try body(UnsafeRawPointer(entry.entry).assumingMemoryBound(to: CChar.self))
  }

  public func withContiguousUTF8Bytes<R>(_ body: (UnsafeRawBufferPointer) -> R) -> R {
    body(.init(start: entry.entry, count: Int(entry.length)))
  }
}

public extension Flac.StreamMetadata.VorbisComment.Entry {

  init(name: String, value: String) throws {
    entry = try withUnsafeTemporaryAllocation(of: FLAC__StreamMetadata_VorbisComment_Entry.self, capacity: 1) { buffer in
      try preconditionOrThrow(FLAC__metadata_object_vorbiscomment_entry_from_name_value_pair(
        buffer.baseAddress, name, value
      ).cBool)
      return buffer[0]
    }
  }

  var string: String {
    withContiguousUTF8Bytes { String(decoding: $0, as: UTF8.self) }
  }

  func splitNameValue() -> (name: LazyCopiedCString, value: LazyCopiedCString)? {
    var field_name: UnsafeMutablePointer<Int8>?
    var field_value: UnsafeMutablePointer<Int8>?
    guard FLAC__metadata_object_vorbiscomment_entry_to_name_value_pair(
      entry, &field_name, &field_value).cBool else {
      return nil
    }
    return (.init(cString: field_name.unsafelyUnwrapped, freeWhenDone: true),
      .init(cString: field_value.unsafelyUnwrapped, freeWhenDone: true))
  }
}

public extension Flac.StreamMetadata.VorbisComment {

  struct Entry: ~Copyable {
    internal init(_ entry: FLAC__StreamMetadata_VorbisComment_Entry) {
      self.entry = entry
    }
    
    let entry: FLAC__StreamMetadata_VorbisComment_Entry
  }

  var commentsCount: UInt32 {
    ptr.pointee.data.vorbis_comment.num_comments
  }

  func withVendorEntry<R>(_ body: (borrowing Entry) throws -> R) rethrows -> R {
    return try body(.init(ptr.pointee.data.vorbis_comment.vendor_string))
  }

  func withEntry<R>(index: Int, _ body: (borrowing Entry) throws -> R) rethrows -> R {
    precondition(index >= 0)
    precondition(index < commentsCount)
    return try body(.init(ptr.pointee.data.vorbis_comment.comments[index]))
  }

  func copyAll() -> [String] {
    (0..<Int(commentsCount)).map { Entry(ptr.pointee.data.vorbis_comment.comments[$0]).string }
  }
}

public extension Flac.StreamMetadata {
  func withVoirbisComment<R>(_ body: (borrowing VorbisComment) throws -> R) rethrows -> R {
    assert(metatype == .vorbisComment)
    let ref = VorbisComment(ptr: ptr)
    return try body(ref)
  }

  mutating func withMutableVoirbisComment<R>(_ body: (inout VorbisComment) throws -> R) rethrows -> R {
    assert(metatype == .vorbisComment)
    var ref = VorbisComment(ptr: ptr)
    return try body(&ref)
  }

  func withApplication<R>(_ body: (borrowing Application) throws -> R) rethrows -> R {
    assert(metatype == .application)
    let ref = Application(ptr: ptr)
    return try body(ref)
  }

  mutating func withMutableApplication<R>(_ body: (inout Application) throws -> R) rethrows -> R {
    assert(metatype == .application)
    var ref = Application(ptr: ptr)
    return try body(&ref)
  }
}

extension ContiguousUTF8Bytes {
  func withVorbisCommentEntry<R>(_ body: (FLAC__StreamMetadata_VorbisComment_Entry) -> R) -> R {
    withContiguousUTF8Bytes { buffer in
      body(.init(length: numericCast(buffer.count), entry: UnsafeMutableRawPointer(mutating: buffer.baseAddress!).assumingMemoryBound(to: UInt8.self)))
    }
  }
}

// MARK: VorbisComment mutations
public extension Flac.StreamMetadata.VorbisComment {

  mutating func set(vendorString: some ContiguousUTF8Bytes) -> Bool {
    vendorString.withVorbisCommentEntry { entry in
      FLAC__metadata_object_vorbiscomment_set_vendor_string(
        ptr, entry, .init(cBool: true)
      ).cBool
    }
  }

  mutating func resize(count: UInt32) -> Bool {
    FLAC__metadata_object_vorbiscomment_resize_comments(
      ptr, count
    ).cBool
  }

  mutating func set(comment: some ContiguousUTF8Bytes, at index: Int) -> Bool {
    comment.withVorbisCommentEntry { entry in
      FLAC__metadata_object_vorbiscomment_set_comment(
        ptr, numericCast(index), entry, .init(cBool: true)
      ).cBool

    }
  }

  mutating func insert(comment: some ContiguousUTF8Bytes, at index: Int) -> Bool {
    comment.withVorbisCommentEntry { entry in
      FLAC__metadata_object_vorbiscomment_insert_comment(
        ptr, numericCast(index), entry, .init(cBool: true)
      ).cBool
    }
  }

  mutating func append(comment: some ContiguousUTF8Bytes) -> Bool {
    comment.withVorbisCommentEntry { entry in
      FLAC__metadata_object_vorbiscomment_append_comment(
        ptr, entry, .init(cBool: true)
      ).cBool
    }
  }

  mutating func replace(with comment: some ContiguousUTF8Bytes, all: Bool = false) -> Bool {
    comment.withVorbisCommentEntry { entry in
      FLAC__metadata_object_vorbiscomment_replace_comment(
        ptr, entry, .init(cBool: all), .init(cBool: true)
      ).cBool
    }
  }

  mutating func delete(at index: UInt32) -> Bool {
    FLAC__metadata_object_vorbiscomment_delete_comment(
      ptr, index
    ).cBool
  }

}

public extension Flac.StreamMetadata.Picture {

  var mimeType: String {
    .init(cString: ptr.pointee.data.picture.mime_type)
  }

  var description: String {
    .init(cString: ptr.pointee.data.picture.description)
  }

  var colors: UInt32 {
    _read { yield ptr.pointee.data.picture.colors }
    _modify { yield &ptr.pointee.data.picture.colors }
  }

  var depth: UInt32 {
    _read { yield ptr.pointee.data.picture.depth }
    _modify { yield &ptr.pointee.data.picture.depth }
  }

  var width: UInt32 {
    _read { yield ptr.pointee.data.picture.width }
    _modify { yield &ptr.pointee.data.picture.width }
  }

  var height: UInt32 {
    _read { yield ptr.pointee.data.picture.height }
    _modify { yield &ptr.pointee.data.picture.height }
  }

  var type: FLAC__StreamMetadata_Picture_Type {
    _read { yield ptr.pointee.data.picture.type }
    _modify { yield &ptr.pointee.data.picture.type }
  }

  var data: UnsafeBufferPointer<UInt8> {
    .init(start: ptr.pointee.data.picture.data, count: numericCast(ptr.pointee.data.picture.data_length))
  }

  mutating func set(mimetype: borrowing DynamicCString) -> Bool {
    mimetype.withMutableCString { cString in
      FLAC__metadata_object_picture_set_mime_type(
        ptr, cString, .init(cBool: true)
      ).cBool
    }
  }

  mutating func set(mimetype: consuming DynamicCString) -> Bool {
    FLAC__metadata_object_picture_set_mime_type(
      ptr, mimetype.take(), .init(cBool: false)
    ).cBool
  }

  mutating func set(buffer: UnsafeRawBufferPointer, copy: Bool = true) -> Bool {
    assert(!buffer.isEmpty)
    let binded = buffer.bindMemory(to: FLAC__byte.self)
    return FLAC__metadata_object_picture_set_data(
      ptr, .init(mutating: binded.baseAddress!),
      numericCast(binded.count), .init(cBool: copy)
    ).cBool
  }
}

public extension Flac.StreamMetadata.Application {

  var applicationID: (UInt8, UInt8, UInt8, UInt8) {
    _read {
      yield ptr.pointee.data.application.id
    }
    mutating _modify {
      yield &ptr.pointee.data.application.id
    }
  }

  var applicationData: UnsafeBufferPointer<UInt8> {
    .init(start: ptr.pointee.data.application.data, count: numericCast(ptr.pointee.length - 4))
  }

  mutating func setApplication(data buffer: UnsafeRawBufferPointer, copy: Bool = true) -> Bool {
    assert(!buffer.isEmpty)
    let binded = buffer.bindMemory(to: FLAC__byte.self)
    return FLAC__metadata_object_application_set_data(
      ptr, .init(mutating: binded.baseAddress!),
      numericCast(binded.count), .init(cBool: copy)
    ).cBool
  }
}
