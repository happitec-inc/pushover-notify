// PushoverError.test.swift — unit tests for PushoverError (pure-function, no network)

import Foundation
import Testing
@testable import notifyCore

@Suite("PushoverError descriptions")
struct PushoverErrorTests {

    @Test("fileReadError description includes the attachment path")
    func testFileReadErrorDescription() {
        let path = "/tmp/test-image.jpg"
        let err = PushoverError.fileReadError(path)
        let desc = err.errorDescription ?? ""
        #expect(desc.contains(path))
        #expect(desc.contains("read"))
    }

    @Test("apiError description includes the message")
    func testApiErrorDescription() {
        let message = "invalid user key"
        let err = PushoverError.apiError(message)
        let desc = err.errorDescription ?? ""
        #expect(desc.contains(message))
        #expect(desc.contains("API"))
    }

    @Test("networkError description mentions the underlying error")
    func testNetworkErrorDescription() {
        let underlying = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."]
        )
        let err = PushoverError.networkError(underlying)
        let desc = err.errorDescription ?? ""
        #expect(desc.contains("Network"))
        // The underlying error's description should be embedded
        #expect(desc.contains("offline") || desc.contains("connection") || desc.contains("Internet"))
    }

    @Test("apiError preserves multi-word messages verbatim")
    func testApiErrorPreservesMultiWordMessage() {
        let message = "token is invalid, user is invalid"
        let err = PushoverError.apiError(message)
        let desc = err.errorDescription ?? ""
        #expect(desc.contains("token is invalid, user is invalid"))
    }
}
