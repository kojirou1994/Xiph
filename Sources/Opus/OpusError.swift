import COpusfile

@_transparent
func throwOpusError(_ code: CInt) throws {
  if code < 0 {
    throw OpusError(code)
  }
}

public struct OpusError: Error, CustomStringConvertible {

  public init(_ code: CInt) {
    self.code = code
  }

  public let code: CInt

  public var description: String {
    .init(cString: opus_strerror(code))
  }
}
