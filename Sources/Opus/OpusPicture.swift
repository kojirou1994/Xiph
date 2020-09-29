import COpusfile
import KwiftExtension
import Foundation

public final class OpusPicture {

  @usableFromInline
  var picture: OpusPictureTag

  @usableFromInline
  var needFree: Bool = false

    public init() {
    picture = .init()
    opus_picture_tag_init(&picture)
  }

    public convenience init(tag: UnsafePointer<Int8>) throws {
    self.init()
    try parse(tag: tag)
  }

    public func parse(tag: UnsafePointer<Int8>) throws {
    clear()
    try throwOpusError(opus_picture_tag_parse(&picture, tag))
    needFree = true
  }

    public func clear() {
    if needFree {
      #if DEBUG
      print(#function)
      #endif
      opus_picture_tag_clear(&picture)
      needFree = false
    }
  }

    deinit {
    clear()
  }
}

extension OpusPicture {
    public var pictureType: Int32 {
    picture.type
  }

    public var mimeType: UnsafeMutablePointer<Int8> {
    picture.mime_type
  }

    public var mimeTypeString: String {
    .init(cString: picture.mime_type)
  }

    public var pictureDescription: UnsafeMutablePointer<Int8> {
    picture.description
  }

    public var pictureDescriptionString: String {
    .init(cString: picture.description)
  }

    public var width: UInt32 {
    picture.width
  }

    public var height: UInt32 {
    picture.height
  }

    public var depth: UInt32 {
    picture.depth
  }

    public var colors: UInt32 {
    picture.colors
  }

    public var data: UnsafeMutableBufferPointer<UInt8> {
    UnsafeMutableBufferPointer(start: picture.data, count: Int(picture.data_length))
  }

  /**The format of the picture data, if known.
   One of
   <ul>
   <li>#OP_PIC_FORMAT_UNKNOWN,</li>
   <li>#OP_PIC_FORMAT_URL,</li>
   <li>#OP_PIC_FORMAT_JPEG,</li>
   <li>#OP_PIC_FORMAT_PNG, or</li>
   <li>#OP_PIC_FORMAT_GIF.</li>
   </ul>*/
    public var format: Int32 {
    picture.format
  }
}

extension OpusPicture: CustomStringConvertible {
  public var description: String {
    "\(pictureType)|\(mimeTypeString)|\(pictureDescriptionString)|\(width)x\(height)x\(depth)|<\(data.count) bytes of image data>"
  }
}
