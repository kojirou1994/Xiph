import opusfile

@dynamicMemberLookup
public final class OpusPicture {

  private var picture: OpusPictureTag

  private var needFree: Bool = false

  public init() {
    picture = .init()
    opus_picture_tag_init(&picture)
  }

  public subscript<T: FixedWidthInteger>(dynamicMember member: KeyPath<OpusPictureTag, T>) -> T {
    get {
      picture[keyPath: member]
    }
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
      opus_picture_tag_clear(&picture)
      needFree = false
    }
  }

  deinit {
    clear()
  }
}

extension OpusPicture {

  public var mimeType: String {
    .init(cString: picture.mime_type)
  }

  public var pictureDescription: String {
    .init(cString: picture.description)
  }

  public var data: UnsafeMutableBufferPointer<UInt8> {
    UnsafeMutableBufferPointer(start: picture.data, count: Int(picture.data_length))
  }

}

extension OpusPicture: CustomStringConvertible {
  public var description: String {
    "\(self.type)|\(mimeType)|\(pictureDescription)|\(self.width)x\(self.height)x\(self.depth)|<\(data.count) bytes of image data>"
  }
}
