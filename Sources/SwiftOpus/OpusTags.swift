import opusfile

@dynamicMemberLookup
public final class OpusTags {

  private let needFree: Bool

  private var tags: opusfile.OpusTags

  internal init(_ tags: opusfile.OpusTags) {
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

  public subscript<T>(dynamicMember member: KeyPath<opusfile.OpusTags, T>) -> T {
    get {
      tags[keyPath: member]
    }
  }
  
  deinit {
    if needFree {
      opus_tags_clear(&tags)
    }
  }
}

extension OpusTags: CustomStringConvertible {

  public var description: String {
    """
    vendor: \(String(cString: self.vendor))
    comments: \(commentsArray)
    """
  }

  public var commentsArray: [String] {
    (0..<Int(self.comments)).map { i in
      let s = String(cString: self.user_comments[i]!)
      assert(s.utf8.count == self.comment_lengths[i])
      return s
    }
  }
}
