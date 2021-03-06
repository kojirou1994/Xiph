#if !canImport(ObjectiveC)
import XCTest

extension FlacStreamMetadataTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__FlacStreamMetadataTests = [
        ("testEntry", testEntry),
        ("testMemory", testMemory),
        ("testPicture", testPicture),
        ("testVorbis", testVorbis),
    ]
}

extension FlacTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__FlacTests = [
        ("testRead", testRead),
    ]
}

public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(FlacStreamMetadataTests.__allTests__FlacStreamMetadataTests),
        testCase(FlacTests.__allTests__FlacTests),
    ]
}
#endif
