import opusfile

@dynamicMemberLookup
public final class OpusHead {

  private let head: UnsafePointer<opusfile.OpusHead>

  internal init(_ head: UnsafePointer<opusfile.OpusHead>) {
    //    self.needFree = false
    self.head = head
  }

  public subscript<T: FixedWidthInteger>(dynamicMember member: KeyPath<opusfile.OpusHead, T>) -> T {
//    set {
//      head.pointee[keyPath: member] = newValue
//    }
//    _modify {
//      yield &head.pointee[keyPath: member]
//    }
    get {
      head.pointee[keyPath: member]
    }
  }

}

extension OpusHead {
  public func withMappingBuffer<R>(_ body: (UnsafeBufferPointer<UInt8>) throws -> R) rethrows -> R {
    try withUnsafeBytes(of: head.pointee.mapping) { buffer in
      try body(buffer.bindMemory(to: UInt8.self))
    }
  }
}

extension OpusHead: CustomStringConvertible {
  public var description: String {
    String(describing: head.pointee)
  }
}
