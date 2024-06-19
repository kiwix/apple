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

import Foundation

enum HTTPSuccess {
    static func response(
        url: URL,
        metaData: URLContentMetaData,
        requestedRange: ClosedRange<UInt>?
    ) -> HTTPURLResponse? {
        if let requestedRange {
            return Self.http206Response(
                url: url,
                metaData: metaData,
                requestedRange: requestedRange
            )
        } else {
            return Self.http200Response(
                url: url,
                metaData: metaData
            )
        }
    }


    private static func http200Response(
        url: URL,
        metaData: URLContentMetaData
    ) -> HTTPURLResponse? {
        var headers = defaultResponseHeaders(for: metaData)
        headers["Content-Length"] = "\(metaData.size)"
        return HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )
    }

    private static func http206Response(
        url: URL,
        metaData: URLContentMetaData,
        requestedRange: ClosedRange<UInt>
    ) -> HTTPURLResponse? {
        var headers = defaultResponseHeaders(for: metaData)
        headers["Content-Length"] = "\(requestedRange.fullRangeSize)"
        headers["Content-Range"] = metaData.contentRange(for: requestedRange)
        return HTTPURLResponse(
            url: url,
            statusCode: 206,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )
    }

    private static func defaultResponseHeaders(for metaData: URLContentMetaData) -> [String: String] {
        var headers = [
            "Accept-Ranges": "bytes",
            "Content-Type": metaData.httpContentType,
            "Date": Date().formatAsGMT()
        ]
        if let modifiedDate = metaData.lastModified {
            headers["Last-Modified"] = modifiedDate.formatAsGMT()
        }
        if let eTag = metaData.eTag {
            headers["ETag"] = eTag
        }
        return headers
    }
}
