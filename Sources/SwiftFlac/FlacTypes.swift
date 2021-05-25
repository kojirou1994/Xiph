import FLAC
import KwiftC

extension Bool {
  @inlinable
  var flacBool: FLAC__bool {
    .init(cBool: false)
  }
}

func checkOggFlacIsSupported() {
  precondition(FLAC_API_SUPPORTS_OGG_FLAC.cBool)
}
