import CReplayGainAnalysis

public enum ReplayGainAnalysis {}

public extension ReplayGainAnalysis {
  static func initialize(sampleFrequency: Int) -> Bool {
    let v = InitGainAnalysis(sampleFrequency)
    if _fastPath(v == INIT_GAIN_ANALYSIS_OK) {
      return true
    }
    assert(v == INIT_GAIN_ANALYSIS_ERROR)
    return false
  }

  static func analyze(leftSamples: UnsafePointer<Float>, rightSamples: UnsafePointer<Float>, samplesCount: Int, channels: Int32) -> Bool {
    AnalyzeSamples(leftSamples, rightSamples, samplesCount, channels) == GAIN_ANALYSIS_OK
  }

  static func reset(sampleFrequency: Int) -> Bool {
    let v = ResetSampleFrequency(sampleFrequency)
    if _fastPath(v == INIT_GAIN_ANALYSIS_OK) {
      return true
    }
    assert(v == INIT_GAIN_ANALYSIS_ERROR)
    return false
  }

  /// recommended dB level change for all samples analyzed SINCE THE LAST TIME you called titleGain getter OR initialize()
  static var titleGain: Float {
    GetTitleGain()
  }

  /// recommended dB level change for all samples analyzed since initialize() was called and finalized with titleGain getter.
  static var albumGain: Float {
    GetAlbumGain()
  }
}
