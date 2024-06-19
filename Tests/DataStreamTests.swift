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

final class DataStreamTests: XCTestCase {

    func test_empty_data() async throws {
        let data = Data()
        XCTAssertNil(
            DataStream(
                dataProvider: MockDataProvider(data: data),
                ranges: []
            )
        )
    }

    func test_small_data() async throws {
        let data = "small test data".data(using: .utf8)!
        let dataStream = DataStream(
            dataProvider: MockDataProvider(data: data),
            ranges: ByteRanges.rangesFor(contentLength: UInt(data.count),
                                         rangeSize: 256)
        )!
        var outData = Data()
        for try await subData in dataStream {
            outData.append(subData)
        }
        XCTAssertEqual(data, outData)
    }

    func test_small_data_with_large_rangeSize_returns_in_one_chunk() async throws {
        let data = "small test data".data(using: .utf8)!
        let dataStream = DataStream(
            dataProvider: MockDataProvider(data: data),
            ranges: ByteRanges.rangesFor(contentLength: UInt(data.count),
                                         rangeSize: 2_000_000)
        )!
        let exp = expectation(description: "data in one chunk")
        exp.expectedFulfillmentCount = 1
        for try await subData in dataStream {
            // make sure the first chunk is already matching the full expected data
            XCTAssertEqual(subData, data)
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 0)
    }

    func test_large_data() async throws {
        var largeString = ""
        let value = UUID().uuidString
        for _ in 0...100_000 {
            largeString.append(value)
        }
        let data = largeString.data(using: .utf8)!
        let dataStream = DataStream(
            dataProvider: MockDataProvider(data: data),
            ranges: ByteRanges.rangesFor(contentLength: UInt(data.count),
                                         rangeSize: 256)
        )!
        var outData = Data()
        for try await subData in dataStream {
            outData.append(subData)
        }
        XCTAssertEqual(data, outData)
    }
}

private struct MockDataProvider: DataProvider {
    typealias Element = Data
    let data: Data

    func data(from start: UInt, to end: UInt) async -> Data? {
        let range = Range<Int>(uncheckedBounds: (Int(start), Int(end+1)))
        return data.subdata(in: range)
    }
}
