import opusfile

public struct OpusHead {

  @usableFromInline
  internal let rawValue: opusfile.OpusHead

//  public subscript<T: FixedWidthInteger>(dynamicMember member: KeyPath<opusfile.OpusHead, T>) -> T {
////    set {
////      head.pointee[keyPath: member] = newValue
////    }
////    _modify {
////      yield &head.pointee[keyPath: member]
////    }
//    get {
//      head.pointee[keyPath: member]
//    }
//  }

}

//extension OpusHead {
//  public func withMappingBuffer<R>(_ body: (UnsafeBufferPointer<UInt8>) throws -> R) rethrows -> R {
//    try withUnsafeBytes(of: head.mapping) { buffer in
//      try body(buffer.bindMemory(to: UInt8.self))
//    }
//  }
//}
