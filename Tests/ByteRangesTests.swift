// This file is part of Kiwix for iOS & macOS.
//
// Kiwix is free software; you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 3 of the License, or
// any later version.
//
// Kiwix is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Kiwix; If not, see https://www.gnu.org/licenses/.

import XCTest
@testable import Kiwix

final class ByteRangesTests: XCTestCase {

    func test_zero_values() {
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 0, rangeSize: 2), [])
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 1, rangeSize: 0), [])
    }

    func test_size_too_large() {
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 1, rangeSize: 2), [0...0])
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 5, rangeSize: 6), [0...4])
    }

    func test_size_one() {
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 1, rangeSize: 1), [0...0])
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 2, rangeSize: 1), [0...0, 1...1])
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 3, rangeSize: 1), [0...0, 1...1, 2...2])
    }

    func test_size_two() {
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 2, rangeSize: 2), [0...1])
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 3, rangeSize: 2), [0...1, 2...2])
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 4, rangeSize: 2), [0...1, 2...3])
    }

    func test_8_bits() {
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 8, rangeSize: 8), [0...7])
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 10, rangeSize: 8), [0...7, 8...9])
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 16, rangeSize: 8), [0...7, 8...15])
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 24, rangeSize: 8), [0...7, 8...15, 16...23])
    }

    func test_offset_start() {
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 1, rangeSize: 1, start: 16), [16...16])
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 1, rangeSize: 8, start: 16), [16...16])
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 2, rangeSize: 8, start: 16), [16...17])
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 3, rangeSize: 2, start: 16), [16...17, 18...18])
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 4, rangeSize: 2, start: 16), [16...17, 18...19])
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 7, rangeSize: 3, start: 3), [3...5, 6...8, 9...9])
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 32, rangeSize: 8, start: 16), [16...23, 24...31, 32...39, 40...47])
    }

    func test_veryLarge_rangeSize_results_in_one_range() {
        let size2MB: UInt = 2_097_152 // 2MB
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 50_001, rangeSize: size2MB), [0...50_000])
        XCTAssertEqual(ByteRanges.rangesFor(contentLength: 2000, rangeSize: size2MB, start: 999), [999...2998])
    }

}
