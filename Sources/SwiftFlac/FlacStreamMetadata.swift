import Foundation
import Precondition

extension FLAC__MetadataType: CustomStringConvertible {
  public var description: String {
    switch self {
    case FLAC__METADATA_TYPE_VORBIS_COMMENT:
      return "VORBIS_COMMENT"
    case FLAC__METADATA_TYPE_PICTURE:
      return "PICTURE"
    case FLAC__METADATA_TYPE_STREAMINFO:
      return "STREAMINFO"
    case FLAC__METADATA_TYPE_PADDING:
      return "PADDING"
    case FLAC__METADATA_TYPE_APPLICATION:
      return "APPLICATION"
    case FLAC__METADATA_TYPE_SEEKTABLE:
      return "SEEKTABLE"
    case FLAC__METADATA_TYPE_CUESHEET:
      return "CUESHEET"
    default:
      return "UNDEFINED(\(rawValue))"
    }
  }
}

public class FlacStreamMetadata {

  let ptr: UnsafeMutablePointer<FLAC__StreamMetadata>

  var owner: AnyObject?

  required init(_ ptr: UnsafeMutablePointer<FLAC__StreamMetadata>,
                owner: AnyObject? = nil) {
    self.ptr = ptr
    self.owner = owner
  }

  init(type: FLAC__MetadataType) throws {
    ptr = try FLAC__metadata_object_new(type).unwrap()
    owner = nil
  }

  static func autoCast(_ ptr: UnsafeMutablePointer<FLAC__StreamMetadata>, owner: AnyObject?) -> FlacStreamMetadata {
    switch ptr.pointee.type {
    case FLAC__METADATA_TYPE_VORBIS_COMMENT:
      return FlacStreamMetadataVorbisComment(ptr, owner: owner)
    case FLAC__METADATA_TYPE_PICTURE:
      return FlacStreamMetadataPicture(ptr, owner: owner)
    case FLAC__METADATA_TYPE_STREAMINFO:
      return FlacStreamMetadataStreamInfo(ptr, owner: owner)
    case FLAC__METADATA_TYPE_PADDING:
      return FlacStreamMetadataPadding(ptr, owner: owner)
    case FLAC__METADATA_TYPE_APPLICATION:
      return FlacStreamMetadataApplication(ptr, owner: owner)
    case FLAC__METADATA_TYPE_SEEKTABLE:
      return FlacStreamMetadataSeektable(ptr, owner: owner)
    case FLAC__METADATA_TYPE_CUESHEET:
      return FlacStreamMetadataCuesheet(ptr, owner: owner)
    default:
      return FlacStreamMetadata(ptr, owner: owner)
    }
  }

  public var isLast: Bool {
    ptr.pointee.is_last.cBool
  }

  public var length: UInt32 {
    ptr.pointee.length
  }

  public var metatype: FLAC__MetadataType {
    ptr.pointee.type
  }

  deinit {
    if owner == nil {
      FLAC__metadata_object_delete(ptr)
    }
  }
}

public extension FlacStreamMetadata {
  func clone() throws -> Self {
    Self(try FLAC__metadata_object_clone(ptr).unwrap())
  }
}

public extension FLAC__StreamMetadata_VorbisComment_Entry {

  init(name: String, value: String) throws {
    self.init()
    try preconditionOrThrow(
      FLAC__metadata_object_vorbiscomment_entry_from_name_value_pair(
        &self, name, value
      ).cBool
    )
  }

  var string: String {
    if length == 0 {
      return .init()
    }
    return .init(cString: entry)
  }

  func toNameValue() throws -> (name: String, value: String) {
    var field_name: UnsafeMutablePointer<Int8>?
    var field_value: UnsafeMutablePointer<Int8>?
    try preconditionOrThrow(
      FLAC__metadata_object_vorbiscomment_entry_to_name_value_pair(
        self, &field_name, &field_value
      ).cBool
    )
    defer {
      free(field_name)
      free(field_value)
    }
    return (String(cString: field_name.unsafelyUnwrapped),
            String(cString: field_value.unsafelyUnwrapped))
  }
}

// MARK: StreamInfo
@dynamicMemberLookup
public final class FlacStreamMetadataStreamInfo: FlacStreamMetadata {

  public convenience init() throws {
    try self.init(type: FLAC__METADATA_TYPE_STREAMINFO)
  }

  public subscript<T>(dynamicMember member: WritableKeyPath<FLAC__StreamMetadata_StreamInfo, T>) -> T {
    get {
      ptr.pointee.data.stream_info[keyPath: member]
    }
  }

}

// MARK: VorbisComment
public final class FlacStreamMetadataVorbisComment: FlacStreamMetadata {

  public convenience init() throws {
    try self.init(type: FLAC__METADATA_TYPE_VORBIS_COMMENT)
  }

}

public extension FlacStreamMetadataVorbisComment {
  var commentsCount: UInt32 {
    ptr.pointee.data.vorbis_comment.num_comments
  }

  var vendorStringEntry: FLAC__StreamMetadata_VorbisComment_Entry {
    ptr.pointee.data.vorbis_comment.vendor_string
  }

  var vendorString: String {
    ptr.pointee.data.vorbis_comment.vendor_string.string
  }

  subscript(index: Int) -> String {
    precondition(index >= 0)
    precondition(index < commentsCount)
    return ptr.pointee.data.vorbis_comment.comments[index].string
  }

  func copyAll() -> [String] {
    (0..<Int(commentsCount)).map { ptr.pointee.data.vorbis_comment.comments[$0].string }
  }
}

extension String {
  func withVorbisCommentEntry<R>(_ body: (FLAC__StreamMetadata_VorbisComment_Entry) throws -> R) rethrows -> R {
    var copy = self
    return try copy.withUTF8 { buffer in
      try body(.init(length: numericCast(buffer.count), entry: .init(mutating: buffer.baseAddress!)))
    }
  }
}

public extension FlacStreamMetadataVorbisComment {

  func set(vendorString: String) throws {
    try vendorString.withVorbisCommentEntry { entry in
      try preconditionOrThrow(
        FLAC__metadata_object_vorbiscomment_set_vendor_string(
          ptr, entry, .init(cBool: true)
        ).cBool
      )
    }
  }
  func resize(count: Int) throws {
    try preconditionOrThrow(
      FLAC__metadata_object_vorbiscomment_resize_comments(
        ptr, numericCast(count)
      ).cBool
    )
  }

  func set(comment: String, at index: Int) throws {
    try comment.withVorbisCommentEntry { entry in
      try preconditionOrThrow(
        FLAC__metadata_object_vorbiscomment_set_comment(
          ptr, numericCast(index), entry, .init(cBool: true)
        ).cBool
      )
    }
  }

  func insert(comment: String, at index: Int) throws {
    try comment.withVorbisCommentEntry { entry in
      try preconditionOrThrow(
        FLAC__metadata_object_vorbiscomment_insert_comment(
          ptr, numericCast(index), entry, .init(cBool: true)
        ).cBool
      )
    }
  }

  func append(comment: String) throws {
    try comment.withVorbisCommentEntry { entry in
      try preconditionOrThrow(
        FLAC__metadata_object_vorbiscomment_append_comment(
          ptr, entry, .init(cBool: true)
        ).cBool
      )
    }
  }

  func replace(with comment: String, all: Bool = false) throws {
    try comment.withVorbisCommentEntry { entry in
      try preconditionOrThrow(
        FLAC__metadata_object_vorbiscomment_replace_comment(
          ptr, entry, .init(cBool: all), .init(cBool: true)
        ).cBool
      )
    }
  }

  func delete(at index: Int) throws {
    try preconditionOrThrow(
      FLAC__metadata_object_vorbiscomment_delete_comment(
        ptr, numericCast(index)
      ).cBool
    )
  }

}

// MARK: Picture
public final class FlacStreamMetadataPicture: FlacStreamMetadata {
  public convenience init() throws {
    try self.init(type: FLAC__METADATA_TYPE_PICTURE)
  }
}

public extension FlacStreamMetadataPicture {
  var mimeType: String {
    .init(cString: ptr.pointee.data.picture.mime_type)
  }

  var description: String {
    .init(cString: ptr.pointee.data.picture.description)
  }

  var colors: UInt32 {
    get {
      ptr.pointee.data.picture.colors
    }
    set {
      ptr.pointee.data.picture.colors = newValue
    }
  }

  var depth: UInt32 {
    get {
      ptr.pointee.data.picture.depth
    }
    set {
      ptr.pointee.data.picture.depth = newValue
    }
  }

  var width: UInt32 {
    get {
      ptr.pointee.data.picture.width
    }
    set {
      ptr.pointee.data.picture.width = newValue
    }
  }

  var height: UInt32 {
    get {
      ptr.pointee.data.picture.height
    }
    set {
      ptr.pointee.data.picture.height = newValue
    }
  }

  var type: FLAC__StreamMetadata_Picture_Type {
    get {
      ptr.pointee.data.picture.type
    }
    set {
      ptr.pointee.data.picture.type = newValue
    }
  }

  var data: UnsafeBufferPointer<UInt8> {
    .init(start: ptr.pointee.data.picture.data, count: numericCast(ptr.pointee.data.picture.data_length))
  }

  func set(mimeType: String) throws {
    try mimeType.withCString { str in
      try set(mimetype: str, copy: true)
    }
  }

  func set(mimetype: UnsafePointer<Int8>, copy: Bool) throws {
    try preconditionOrThrow(
      FLAC__metadata_object_picture_set_mime_type(
        ptr, .init(mutating: mimetype), .init(cBool: copy)
      ).cBool
    )
  }

  func set(description: String) throws {
    var copy = description
    try copy.withUTF8 { str in
      try preconditionOrThrow(
        FLAC__metadata_object_picture_set_description(
          ptr, .init(mutating: str.baseAddress!), .init(cBool: true)
        ).cBool
      )
    }
  }

  func set<B: ContiguousBytes>(data: B, copy: Bool = true) throws {
    try data.withUnsafeBytes { buffer in
      precondition(!buffer.isEmpty)
      let binded = buffer.bindMemory(to: FLAC__byte.self)
      try preconditionOrThrow(
        FLAC__metadata_object_picture_set_data(
          ptr, .init(mutating: binded.baseAddress!),
          numericCast(binded.count), .init(cBool: copy)
        ).cBool
      )
    }
  }
}

// MARK: Padding
public final class FlacStreamMetadataPadding: FlacStreamMetadata {

  public convenience init() throws {
    try self.init(type: FLAC__METADATA_TYPE_PADDING)
  }

}

// MARK: Application
public final class FlacStreamMetadataApplication: FlacStreamMetadata {

  public convenience init() throws {
    try self.init(type: FLAC__METADATA_TYPE_APPLICATION)
  }

}

public extension FlacStreamMetadataApplication {

  var id: String {
    get {
      withUnsafeBytes(of: ptr.pointee.data.application.id) { buffer in
        String(decoding: buffer, as: UTF8.self)
      }
    }
    set {
      let utf8 = newValue.utf8
      precondition(utf8.count == 4)
      let bytes = Array(utf8)
      ptr.pointee.data.application.id = (bytes[0], bytes[1], bytes[2], bytes[3])
    }
  }

  var data: UnsafeBufferPointer<UInt8> {
    .init(start: ptr.pointee.data.application.data, count: numericCast(length - 4))
  }

  func set<B: ContiguousBytes>(data: B, copy: Bool = true) throws {
    try data.withUnsafeBytes { buffer in
      precondition(!buffer.isEmpty)
      let binded = buffer.bindMemory(to: FLAC__byte.self)
      try preconditionOrThrow(
        FLAC__metadata_object_application_set_data(
          ptr, .init(mutating: binded.baseAddress!),
          numericCast(binded.count), .init(cBool: copy)
        ).cBool
      )
    }
  }
}

// MARK: Seektable
public final class FlacStreamMetadataSeektable: FlacStreamMetadata {

  public convenience init() throws {
    try self.init(type: FLAC__METADATA_TYPE_SEEKTABLE)
  }

}

public extension FlacStreamMetadataSeektable {

}

// MARK: Cuesheet
public final class FlacStreamMetadataCuesheet: FlacStreamMetadata {

  public convenience init() throws {
    try self.init(type: FLAC__METADATA_TYPE_CUESHEET)
  }

}

public extension FlacStreamMetadataCuesheet {

}

extension FlacStreamMetadata: Equatable {
  public static func == (lhs: FlacStreamMetadata, rhs: FlacStreamMetadata) -> Bool {
    FLAC__metadata_object_is_equal(lhs.ptr, rhs.ptr).cBool
  }
}