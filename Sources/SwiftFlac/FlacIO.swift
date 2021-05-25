public enum FlacIO<StreamDelegate> {
  case file(String)
  case cfile(UnsafeMutablePointer<FILE>)
  case oggFile(String)
  case oggCFile(UnsafeMutablePointer<FILE>)
  case stream(StreamDelegate)
  case oggStream(StreamDelegate)

  var isOgg: Bool {
    switch self {
    case .oggFile, .oggCFile, .oggStream:
      return true
    default:
      return false
    }
  }

  mutating func withUnsafeMutableStreamDelegate<T>(_ closure: (inout StreamDelegate) -> T) -> T {
    let result: T
    switch self {
    case .stream(var provider):
      result = closure(&provider)
      self = .stream(provider)
    case .oggStream(var provider):
      result = closure(&provider)
      self = .oggStream(provider)
    default:
      fatalError()
    }
    return result
  }
}

public typealias FlacInput = FlacIO<FlacDecoderStreamDelegate>
public typealias FlacOutput = FlacIO<FlacEncoderStreamDelegate>
