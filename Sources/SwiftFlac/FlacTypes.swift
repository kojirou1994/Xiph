import FLAC
import CUtility

func checkOggFlacIsSupported() {
  precondition(FLAC_API_SUPPORTS_OGG_FLAC.cBool)
}
