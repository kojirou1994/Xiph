import CFlac

extension Bool {
  @inlinable
  var flacBool: FLAC__bool {
    self ? 1 : 0
  }
}

func checkOggFlacIsSupported() {
  precondition(FLAC_API_SUPPORTS_OGG_FLAC.cBool)
}
