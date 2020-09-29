import COpusfile
import KwiftExtension
import Foundation

public final class OpusTags {

  @usableFromInline
  let needFree: Bool

  @usableFromInline
  var tags: COpusfile.OpusTags

  @usableFromInline
  internal init(tags: COpusfile.OpusTags) {
    self.needFree = false
    self.tags = tags
  }

    public init() {
    tags = .init()
    opus_tags_init(&tags)
    needFree = true
  }

    public init(buffer: UnsafeBufferPointer<UInt8>) throws {
    tags = .init()
    try throwOpusError(opus_tags_parse(&tags, buffer.baseAddress.unwrap(), buffer.count))
    needFree = true
  }

    public func add(tag: String, value: String) throws {
    try throwOpusError(opus_tags_add(&tags, tag, value))
  }

    public func add(comment: String) throws {
    try throwOpusError(opus_tags_add_comment(&tags, comment))
  }
  
    deinit {
    if needFree {
      opus_tags_clear(&tags)
    }
  }
}

extension OpusTags {

    public var userComments: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?> {
    tags.user_comments
  }

    public var commentLengths: UnsafeMutablePointer<Int32> {
    tags.comment_lengths
  }

    public var comments: Int32 {
    tags.comments
  }

    public var vendor: UnsafeMutablePointer<Int8> {
    tags.vendor
  }
}

extension OpusTags: CustomStringConvertible {
  public var description: String {
    """
    vendor: \(String(cString: vendor))
    comments: \(commentsArray)
    """
  }

  public var commentsArray: [String] {
    (0..<Int(comments)).map { i in
      let s = String(cString: userComments[i]!)
      assert(s.utf8.count == commentLengths[i])
      return s
    }
  }
}
