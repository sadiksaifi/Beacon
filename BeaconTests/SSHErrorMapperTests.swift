import Foundation
import Testing
@testable import Beacon

@Suite("SSH Error Mapper")
struct SSHErrorMapperTests {
    @Test func timeoutErrorMapsToTimedOut() {
        let message = SSHErrorMapper.message(for: ConnectionTimeoutError())
        #expect(message == "Connection timed out")
    }

    @Test func connectionRefusedMapsCorrectly() {
        let error = NSError(domain: NSPOSIXErrorDomain, code: 61) // ECONNREFUSED
        let message = SSHErrorMapper.message(for: error)
        #expect(message == "Connection refused")
    }

    @Test func networkUnreachableMapsCorrectly() {
        let error = NSError(domain: NSPOSIXErrorDomain, code: 51) // ENETUNREACH
        let message = SSHErrorMapper.message(for: error)
        #expect(message == "Network unavailable")
    }

    @Test func networkDownMapsCorrectly() {
        let error = NSError(domain: NSPOSIXErrorDomain, code: 50) // ENETDOWN
        let message = SSHErrorMapper.message(for: error)
        #expect(message == "Network unavailable")
    }

    @Test func urlErrorNotConnectedMapsToNetworkUnavailable() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        let message = SSHErrorMapper.message(for: error)
        #expect(message == "Network unavailable")
    }

    @Test func urlErrorTimedOutMapsCorrectly() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        let message = SSHErrorMapper.message(for: error)
        #expect(message == "Connection timed out")
    }

    @Test func unknownErrorProducesFallbackMessage() {
        let error = NSError(domain: "TestDomain", code: 999, userInfo: [
            NSLocalizedDescriptionKey: "Something went wrong"
        ])
        let message = SSHErrorMapper.message(for: error)
        #expect(message.contains("Something went wrong"))
        #expect(!message.isEmpty)
    }
}
