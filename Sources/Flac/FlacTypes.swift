import CFlac

extension Bool {
  @inlinable
  var flacBool: FLAC__bool {
    self ? 1 : 0
  }
}
