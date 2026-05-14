// Config.test.swift — unit tests for Config.swift (pure-function, no network)

import Foundation
import Testing
@testable import notifyCore

// ---------------------------------------------------------------------------
// Config.parseConfigFile — tests for the KEY=VALUE parser
// ---------------------------------------------------------------------------

@Suite("Config.parseConfigFile")
struct ConfigParseTests {

    @Test("Parses a basic USER_KEY and API_TOKEN pair")
    func testBasicKeyValueParsing() throws {
        let content = """
        USER_KEY=user-test-key-abcdef
        API_TOKEN=app-test-token-abcdef
        """
        let tmp = try writeTempFile(contents: content)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let result = try Config.parseConfigFile(at: tmp.path)

        #expect(result["USER_KEY"] == "user-test-key-abcdef")
        #expect(result["API_TOKEN"] == "app-test-token-abcdef")
    }

    @Test("Skips comment lines that start with #")
    func testCommentLinesAreSkipped() throws {
        let content = """
        # This is a comment
        USER_KEY=user-test-key-abcdef
        # Another comment
        API_TOKEN=app-test-token-abcdef
        """
        let tmp = try writeTempFile(contents: content)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let result = try Config.parseConfigFile(at: tmp.path)

        #expect(result.count == 2)
        #expect(result["USER_KEY"] == "user-test-key-abcdef")
        #expect(result["API_TOKEN"] == "app-test-token-abcdef")
    }

    @Test("Skips blank lines")
    func testBlankLinesAreSkipped() throws {
        let content = """
        USER_KEY=user-test-key-abcdef

        API_TOKEN=app-test-token-abcdef

        """
        let tmp = try writeTempFile(contents: content)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let result = try Config.parseConfigFile(at: tmp.path)

        #expect(result.count == 2)
    }

    @Test("Splits on first equals sign only; values with embedded = are preserved")
    func testValueWithEmbeddedEquals() throws {
        let content = "SOME_KEY=abc==def==ghi"
        let tmp = try writeTempFile(contents: content)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let result = try Config.parseConfigFile(at: tmp.path)

        // Everything after the first '=' is the value, including any embedded '=' characters.
        #expect(result["SOME_KEY"] == "abc==def==ghi")
    }

    @Test("Returns empty dict when file does not exist")
    func testMissingFileReturnsEmptyDict() throws {
        let result = try Config.parseConfigFile(at: "/tmp/totally-nonexistent-config-file-xyz123")
        #expect(result.isEmpty)
    }

    @Test("Trims surrounding whitespace from keys and values")
    func testWhitespaceTrimming() throws {
        let content = "  USER_KEY  =  user-test-key-abcdef  "
        let tmp = try writeTempFile(contents: content)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let result = try Config.parseConfigFile(at: tmp.path)

        #expect(result["USER_KEY"] == "user-test-key-abcdef")
    }
}

// ---------------------------------------------------------------------------
// Config.loadCredentials — tests for credential resolution
// ---------------------------------------------------------------------------

@Suite("Config.loadCredentials")
struct ConfigLoadCredentialsTests {

    @Test("Returns credentials from config file when no CLI args provided")
    func testCredentialsFromConfigFile() throws {
        let content = """
        USER_KEY=user-test-key-abcdef
        API_TOKEN=app-test-token-abcdef
        """
        let tmp = try writeTempFile(contents: content)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let credentials = try Config.loadCredentials(
            configFilePath: tmp.path,
            userKeyArg: nil,
            apiTokenArg: nil
        )

        #expect(credentials.userKey == "user-test-key-abcdef")
        #expect(credentials.apiToken == "app-test-token-abcdef")
    }

    @Test("CLI --user-key overrides the config file value")
    func testCliUserKeyOverridesConfig() throws {
        let content = """
        USER_KEY=config-user-key
        API_TOKEN=app-test-token-abcdef
        """
        let tmp = try writeTempFile(contents: content)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let credentials = try Config.loadCredentials(
            configFilePath: tmp.path,
            userKeyArg: "cli-override-user-key",
            apiTokenArg: nil
        )

        #expect(credentials.userKey == "cli-override-user-key")
        // Config value still used for the token since no CLI override
        #expect(credentials.apiToken == "app-test-token-abcdef")
    }

    @Test("CLI --api-token overrides the config file value")
    func testCliApiTokenOverridesConfig() throws {
        let content = """
        USER_KEY=user-test-key-abcdef
        API_TOKEN=config-api-token
        """
        let tmp = try writeTempFile(contents: content)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let credentials = try Config.loadCredentials(
            configFilePath: tmp.path,
            userKeyArg: nil,
            apiTokenArg: "cli-override-api-token"
        )

        #expect(credentials.userKey == "user-test-key-abcdef")
        #expect(credentials.apiToken == "cli-override-api-token")
    }

    @Test("Both CLI args override both config file values")
    func testBothCliArgsOverrideConfig() throws {
        let content = """
        USER_KEY=config-user-key
        API_TOKEN=config-api-token
        """
        let tmp = try writeTempFile(contents: content)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let credentials = try Config.loadCredentials(
            configFilePath: tmp.path,
            userKeyArg: "cli-user-key",
            apiTokenArg: "cli-api-token"
        )

        #expect(credentials.userKey == "cli-user-key")
        #expect(credentials.apiToken == "cli-api-token")
    }

    @Test("Throws missingCredentials when config file missing and no CLI args")
    func testMissingCredentialsNoFileNoCli() throws {
        #expect(throws: ConfigError.missingCredentials) {
            try Config.loadCredentials(
                configFilePath: "/tmp/totally-nonexistent-config-file-xyz123",
                userKeyArg: nil,
                apiTokenArg: nil
            )
        }
    }

    @Test("Throws missingCredentials when config has only USER_KEY and no CLI token")
    func testMissingCredentialsPartialConfig() throws {
        let content = "USER_KEY=user-test-key-abcdef"
        let tmp = try writeTempFile(contents: content)
        defer { try? FileManager.default.removeItem(at: tmp) }

        #expect(throws: ConfigError.missingCredentials) {
            try Config.loadCredentials(
                configFilePath: tmp.path,
                userKeyArg: nil,
                apiTokenArg: nil
            )
        }
    }

    @Test("Succeeds with only CLI args and no config file at all")
    func testSucceedsWithOnlyCliArgs() throws {
        let credentials = try Config.loadCredentials(
            configFilePath: nil,
            userKeyArg: "cli-user-key",
            apiTokenArg: "cli-api-token"
        )

        #expect(credentials.userKey == "cli-user-key")
        #expect(credentials.apiToken == "cli-api-token")
    }

    @Test("CLI args alone — no config path — succeed even without any file on disk")
    func testCliArgsAloneNoConfigPath() throws {
        let credentials = try Config.loadCredentials(
            configFilePath: nil,
            userKeyArg: "user-test-key-abcdef",
            apiTokenArg: "app-test-token-abcdef"
        )

        #expect(credentials.userKey == "user-test-key-abcdef")
        #expect(credentials.apiToken == "app-test-token-abcdef")
    }
}

// ---------------------------------------------------------------------------
// ConfigError — error description tests
// ---------------------------------------------------------------------------

@Suite("ConfigError descriptions")
struct ConfigErrorTests {

    @Test("missingCredentials error description mentions config file path and CLI flags")
    func testMissingCredentialsDescription() {
        let err = ConfigError.missingCredentials
        let desc = err.errorDescription ?? ""
        #expect(desc.contains("~/.config/pushover-notify/config"))
        #expect(desc.contains("--user-key"))
        #expect(desc.contains("--api-token"))
    }

    @Test("fileReadError description includes the path")
    func testFileReadErrorDescription() {
        let path = "/some/test/path/config"
        let err = ConfigError.fileReadError(path)
        let desc = err.errorDescription ?? ""
        #expect(desc.contains(path))
    }
}
