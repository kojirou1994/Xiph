import FLAC
import CUtility

// base namespace
public enum Flac {}

// MARK: export.h
public extension Flac {

  static var apiVersionCurrent: Int32 {
    FLAC_API_VERSION_CURRENT
  }

  static var apiVersionRevision: Int32 {
    FLAC_API_VERSION_REVISION
  }

  static var apiVersionAge: Int32 {
    FLAC_API_VERSION_AGE
  }

  static var supportsOggFlac: Bool {
    FLAC_API_SUPPORTS_OGG_FLAC.cBool
  }

}

// MARK: format.h
public extension Flac {
  typealias ChannelAssignment = FLAC__ChannelAssignment

  struct Frame: ~Copyable {
    internal let frame: UnsafePointer<FLAC__Frame>

    public typealias Header = FLAC__FrameHeader
    public typealias Footer = FLAC__FrameFooter

    public var header: Header {
      frame.pointee.header
    }

    public var footer: Footer {
      frame.pointee.footer
    }
  }

  // MARK: Utility functions

  /// Tests that a sample rate is valid for FLAC.
  /// - Parameter sampleRate: The sample rate to test for compliance.
  /// - Returns: true if the given sample rate conforms to the specification, else false
  static func isValid(sampleRate: UInt32) -> Bool {
    FLAC__format_sample_rate_is_valid(sampleRate).cBool
  }
  
  /// Tests that a blocksize at the given sample rate is valid for the FLAC subset.
  /// - Parameters:
  ///   - blockSize: The blocksize to test for compliance.
  ///   - sampleRate: The sample rate is needed, since the valid subset blocksize depends on the sample rate.
  /// - Returns: true if the given blocksize conforms to the specification for the subset at the given sample rate, else false.
  static func isValidForSubset(blockSize: UInt32, sampleRate: UInt32) -> Bool {
    FLAC__format_blocksize_is_subset(blockSize, sampleRate).cBool
  }
  
  /// Tests that a sample rate is valid for the FLAC subset.  The subset rules for valid sample rates are slightly more complex since the rate has to
  /// be expressible completely in the frame header.
  /// - Parameter sampleRate: The sample rate to test for compliance.
  /// - Returns: true if the given sample rate conforms to the specification for the subset, else false.
  static func isValidForSubset(sampleRate: UInt32) -> Bool {
    FLAC__format_sample_rate_is_subset(sampleRate).cBool
  }
  
  /// Check a Vorbis comment entry name to see if it conforms to the Vorbis
  /// comment specification.
  ///  Vorbis comment names must be composed only of characters from [0x20-0x3C,0x3E-0x7D].
  /// - Parameter name: A NUL-terminated string to be checked.
  /// - Returns: false if entry name is illegal, else true.
  static func isValidForVorbisCommentEntry(name: UnsafePointer<CChar>) -> Bool {
    FLAC__format_vorbiscomment_entry_name_is_legal(name).cBool
  }
}

public extension Flac.ChannelAssignment {
  static var independent: Self { FLAC__CHANNEL_ASSIGNMENT_INDEPENDENT }
  static var leftSize: Self { FLAC__CHANNEL_ASSIGNMENT_LEFT_SIDE }
  static var rightSize: Self { FLAC__CHANNEL_ASSIGNMENT_RIGHT_SIDE }
  static var midSide: Self { FLAC__CHANNEL_ASSIGNMENT_MID_SIDE }
}
