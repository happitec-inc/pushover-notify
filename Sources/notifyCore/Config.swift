import Foundation

public enum ConfigError: LocalizedError, Equatable {
    case missingCredentials
    case fileReadError(String)

    public var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Missing credentials. Provide via config file (~/.config/pushover-notify/config) or --user-key/--api-token"
        case .fileReadError(let path):
            return "Could not read config file at: \(path)"
        }
    }
}

public struct Credentials {
    public let userKey: String
    public let apiToken: String
}

public struct Config {
    private static let configDir = ".config/pushover-notify"
    private static let configFile = "config"

    /// Load credentials from config file and CLI arguments (CLI args take priority)
    public static func loadCredentials(userKeyArg: String?, apiTokenArg: String?) throws -> Credentials {
        // Start with config file values
        var userKey: String? = nil
        var apiToken: String? = nil

        // Try to load from config file
        if let configPath = getConfigPath() {
            let configValues = try? parseConfigFile(at: configPath)
            userKey = configValues?["USER_KEY"]
            apiToken = configValues?["API_TOKEN"]
        }

        // Override with CLI arguments if provided
        if let argUserKey = userKeyArg {
            userKey = argUserKey
        }
        if let argApiToken = apiTokenArg {
            apiToken = argApiToken
        }

        // Validate we have both credentials
        guard let finalUserKey = userKey, let finalApiToken = apiToken else {
            throw ConfigError.missingCredentials
        }

        return Credentials(userKey: finalUserKey, apiToken: finalApiToken)
    }

    /// Load credentials from an explicit config file path and CLI arguments (CLI args take priority).
    /// Used by tests to inject a synthetic config path without touching $HOME.
    public static func loadCredentials(
        configFilePath: String?,
        userKeyArg: String?,
        apiTokenArg: String?
    ) throws -> Credentials {
        var userKey: String? = nil
        var apiToken: String? = nil

        if let path = configFilePath {
            let configValues = try? parseConfigFile(at: path)
            userKey = configValues?["USER_KEY"]
            apiToken = configValues?["API_TOKEN"]
        }

        if let argUserKey = userKeyArg {
            userKey = argUserKey
        }
        if let argApiToken = apiTokenArg {
            apiToken = argApiToken
        }

        guard let finalUserKey = userKey, let finalApiToken = apiToken else {
            throw ConfigError.missingCredentials
        }

        return Credentials(userKey: finalUserKey, apiToken: finalApiToken)
    }

    /// Get the full path to config file
    private static func getConfigPath() -> String? {
        guard let homeDir = ProcessInfo.processInfo.environment["HOME"] else {
            return nil
        }
        return "\(homeDir)/\(configDir)/\(configFile)"
    }

    /// Parse .env style config file (KEY=VALUE format).
    /// Internal visibility so tests can exercise the parser directly via @testable import.
    static func parseConfigFile(at path: String) throws -> [String: String] {
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            return [:] // File doesn't exist or can't read - that's OK
        }

        var config: [String: String] = [:]

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Parse KEY=VALUE
            if let separatorIndex = trimmed.firstIndex(of: "=") {
                let key = trimmed[..<separatorIndex].trimmingCharacters(in: .whitespaces)
                let value = trimmed[trimmed.index(after: separatorIndex)...].trimmingCharacters(in: .whitespaces)
                config[String(key)] = String(value)
            } else {
                // Malformed line - print warning but continue
                fputs("Warning: Ignoring malformed config line: \(trimmed)\n", stderr)
            }
        }

        return config
    }
}
