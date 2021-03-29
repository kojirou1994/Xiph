import CFlac

extension Bool {
  @inlinable
  var flacBool: FLAC__bool {
    self ? 1 : 0
  }
}

extension FLAC__bool {
  @inlinable
  var boolValue: Bool {
    self == 0 ? false : true
  }
}
