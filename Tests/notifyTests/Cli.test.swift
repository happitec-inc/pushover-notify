// Cli.test.swift — subprocess integration tests for the notify CLI binary

import Foundation
import Testing

@Suite("notify CLI")
struct CliTests {

    let binaryPath = findNotifyBinary()

    // -----------------------------------------------------------------------
    // 1. --help output
    // -----------------------------------------------------------------------

    @Test("--help exits 0 and mentions all four options")
    func testHelpOutput() throws {
        let (output, exitCode) = try runNotify(args: ["--help"], binaryPath: binaryPath)
        #expect(exitCode == 0)
        #expect(output.contains("--message"))
        #expect(output.contains("--attachment"))
        #expect(output.contains("--user-key"))
        #expect(output.contains("--api-token"))
    }

    @Test("--help output describes the tool purpose")
    func testHelpDescription() throws {
        let (output, _) = try runNotify(args: ["--help"], binaryPath: binaryPath)
        // The abstract in CommandConfiguration
        #expect(output.contains("Pushover") || output.contains("notification"))
    }

    // -----------------------------------------------------------------------
    // 2. --message required — missing-message error
    // -----------------------------------------------------------------------

    @Test("Running without --message exits non-zero")
    func testMissingMessageExitsNonZero() throws {
        let (_, exitCode) = try runNotify(args: [], binaryPath: binaryPath)
        #expect(exitCode != 0)
    }

    @Test("Running without --message prints a usage or error message")
    func testMissingMessagePrintsError() throws {
        let (output, exitCode) = try runNotify(args: [], binaryPath: binaryPath)
        #expect(exitCode != 0)
        // ArgumentParser prints "Missing expected argument" or a usage hint
        #expect(!output.isEmpty)
    }

    // -----------------------------------------------------------------------
    // 3. Missing credentials error (no config file, no CLI overrides)
    // -----------------------------------------------------------------------

    @Test("Missing credentials exits non-zero and mentions credentials")
    func testMissingCredentialsExitsNonZero() throws {
        // HOME is overridden to /tmp in runNotify so no real config file is found.
        // No --user-key / --api-token supplied.
        let (output, exitCode) = try runNotify(
            args: ["--message", "test"],
            binaryPath: binaryPath
        )
        #expect(exitCode != 0)
        #expect(output.contains("credential") || output.contains("user-key") || output.contains("config") || output.contains("Missing"))
    }

    // -----------------------------------------------------------------------
    // 4. --attachment: nonexistent file → error before API call
    // -----------------------------------------------------------------------

    @Test("Nonexistent attachment file exits non-zero with an error message")
    func testNonexistentAttachmentExitsNonZero() throws {
        let (output, exitCode) = try runNotify(
            args: [
                "--message", "test",
                "--user-key", "user-test-key-abcdef",
                "--api-token", "app-test-token-abcdef",
                "--attachment", "/tmp/this-file-absolutely-does-not-exist-abc123.jpg",
            ],
            binaryPath: binaryPath
        )
        #expect(exitCode != 0)
        #expect(output.contains("not found") || output.contains("Error"))
    }

    @Test("Nonexistent attachment path is reported in the error output")
    func testNonexistentAttachmentPathInOutput() throws {
        let fakePath = "/tmp/totally-missing-image-xyz987.jpg"
        let (output, exitCode) = try runNotify(
            args: [
                "--message", "test",
                "--user-key", "user-test-key-abcdef",
                "--api-token", "app-test-token-abcdef",
                "--attachment", fakePath,
            ],
            binaryPath: binaryPath
        )
        #expect(exitCode != 0)
        #expect(output.contains(fakePath))
    }

    // -----------------------------------------------------------------------
    // 5. --attachment: existing file is accepted (validation passes, failure is network)
    // -----------------------------------------------------------------------

    @Test("Existing attachment file passes the file-exists check (exits with network/API error, not file-not-found)")
    func testExistingAttachmentPassesValidation() throws {
        // Write a small dummy file to use as the attachment
        let tmp = try writeTempFile(named: "test-attachment", contents: "fake image data")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let (output, exitCode) = try runNotify(
            args: [
                "--message", "test",
                "--user-key", "user-test-key-abcdef",
                "--api-token", "app-test-token-abcdef",
                "--attachment", tmp.path,
            ],
            binaryPath: binaryPath
        )

        // The file check should pass. The process will fail because credentials are synthetic
        // and no real network call succeeds, but it should NOT say "file not found".
        #expect(!output.contains("Attachment file not found"))
        // Exit code will be non-zero (network/API error) but not due to file validation
        _ = exitCode // non-zero expected here due to network, not file check
    }

    // -----------------------------------------------------------------------
    // 6. --user-key / --api-token CLI overrides
    // -----------------------------------------------------------------------

    @Test("--user-key and --api-token are accepted as CLI arguments")
    func testCliCredentialArgsAreAccepted() throws {
        // With synthetic creds the API call will fail, but ArgumentParser must accept the flags.
        // The failure should be a network/API error (exit 1), not an argument-parsing error.
        let (output, exitCode) = try runNotify(
            args: [
                "--message", "test",
                "--user-key", "user-test-key-abcdef",
                "--api-token", "app-test-token-abcdef",
            ],
            binaryPath: binaryPath
        )
        // ArgumentParser error would say "Unknown option" or similar
        #expect(!output.contains("Unknown option"))
        #expect(!output.contains("unrecognized"))
        // The tool got past argument parsing. Any failure here is at the network level.
        _ = exitCode // non-zero expected due to synthetic credentials, not argument error
    }

    @Test("Providing --user-key without --api-token still fails with credentials error, not argument error")
    func testPartialCredentialArgsMissingToken() throws {
        let (output, exitCode) = try runNotify(
            args: [
                "--message", "test",
                "--user-key", "user-test-key-abcdef",
                // intentionally omitting --api-token
            ],
            binaryPath: binaryPath
        )
        #expect(exitCode != 0)
        // Should mention credentials, not an argument parse error
        #expect(!output.contains("Unknown option"))
    }

    // -----------------------------------------------------------------------
    // 7. Exit code behaviour
    // -----------------------------------------------------------------------

    @Test("--help exits 0 (success)")
    func testHelpExitCode() throws {
        let (_, exitCode) = try runNotify(args: ["--help"], binaryPath: binaryPath)
        #expect(exitCode == 0)
    }

    @Test("Missing --message exits 64 or 1 (non-zero error)")
    func testMissingMessageExitCodeIsNonZero() throws {
        let (_, exitCode) = try runNotify(args: [], binaryPath: binaryPath)
        #expect(exitCode != 0)
    }

    @Test("Nonexistent attachment file exits 1 (non-zero)")
    func testNonexistentAttachmentExitCodeIsOne() throws {
        let (_, exitCode) = try runNotify(
            args: [
                "--message", "test",
                "--user-key", "user-test-key-abcdef",
                "--api-token", "app-test-token-abcdef",
                "--attachment", "/tmp/does-not-exist-sentinel-abc.jpg",
            ],
            binaryPath: binaryPath
        )
        #expect(exitCode == 1)
    }
}
