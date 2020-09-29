import XCTest

import FlacTests
import OpusTests

var tests = [XCTestCaseEntry]()
tests += FlacTests.__allTests()
tests += OpusTests.__allTests()

XCTMain(tests)
