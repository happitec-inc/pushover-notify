# Pushover Notify CLI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Swift CLI tool that sends Pushover notifications with image attachments using swift-openapi-generator for type-safe API interactions.

**Architecture:** Single executable target with ArgumentParser for CLI, swift-openapi-generator for API client, credentials from .env-style config file with CLI override support.

**Tech Stack:** Swift 5.9+, ArgumentParser, swift-openapi-generator, swift-openapi-runtime, swift-openapi-urlsession

---

## Task 1: Initialize Swift Package

**Files:**
- Create: `Package.swift`

**Step 1: Initialize Swift package**

Run:
```bash
swift package init --type executable --name pushover-notify
```

Expected: Package structure created with Sources/pushover-notify/main.swift

**Step 2: Verify build works**

Run:
```bash
swift build
```

Expected: BUILD SUCCEEDED with default "Hello, World!" executable

**Step 3: Test default executable**

Run:
```bash
swift run pushover-notify
```

Expected: Output "Hello, World!"

**Step 4: Commit initial package**

```bash
git init
git add .
git commit -m "feat: initialize Swift package"
```

---

## Task 2: Configure Package Dependencies

**Files:**
- Modify: `Package.swift`

**Step 1: Update Package.swift with dependencies**

Replace entire contents with:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "pushover-notify",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "notify",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
            ]
        ),
    ]
)
```

**Step 2: Rename executable directory**

Run:
```bash
mv Sources/pushover-notify Sources/notify
```

Expected: Directory renamed

**Step 3: Resolve dependencies**

Run:
```bash
swift package resolve
```

Expected: Fetching and resolving all dependencies, should complete successfully

**Step 4: Verify build**

Run:
```bash
swift build
```

Expected: BUILD SUCCEEDED (may take time to download dependencies)

**Step 5: Commit package configuration**

```bash
git add Package.swift Package.resolved
git commit -m "feat: add ArgumentParser and OpenAPI dependencies"
```

---

## Task 3: Create OpenAPI Specification

**Files:**
- Create: `openapi.yaml`
- Create: `openapi-generator-config.yaml`

**Step 1: Create OpenAPI spec for Pushover API**

Create `openapi.yaml` at package root:

```yaml
openapi: 3.1.0
info:
  title: Pushover API
  version: 1.0.0
  description: Minimal Pushover API specification for sending notifications with attachments
servers:
  - url: https://api.pushover.net/1
    description: Pushover API server

paths:
  /messages.json:
    post:
      operationId: sendMessage
      summary: Send a notification
      requestBody:
        required: true
        content:
          multipart/form-data:
            schema:
              type: object
              required:
                - token
                - user
                - message
              properties:
                token:
                  type: string
                  description: Application API token
                user:
                  type: string
                  description: User key
                message:
                  type: string
                  description: Notification message
                attachment:
                  type: string
                  format: binary
                  description: Image attachment
      responses:
        '200':
          description: Notification sent successfully
          content:
            application/json:
              schema:
                type: object
                properties:
                  status:
                    type: integer
                  request:
                    type: string
        '400':
          description: Invalid request
          content:
            application/json:
              schema:
                type: object
                properties:
                  status:
                    type: integer
                  errors:
                    type: array
                    items:
                      type: string
```

**Step 2: Create OpenAPI generator configuration**

Create `openapi-generator-config.yaml` at package root:

```yaml
generate:
  - types
  - client
accessModifier: internal
```

**Step 3: Verify generator can read spec**

Run:
```bash
swift build
```

Expected: Build should process openapi.yaml and generate client code (you may see warnings, that's OK)

**Step 4: Commit OpenAPI files**

```bash
git add openapi.yaml openapi-generator-config.yaml
git commit -m "feat: add OpenAPI specification for Pushover API"
```

---

## Task 4: Implement Configuration Loader

**Files:**
- Create: `Sources/notify/Config.swift`

**Step 1: Create Config.swift with credential loading**

Create `Sources/notify/Config.swift`:

```swift
import Foundation

enum ConfigError: LocalizedError {
    case missingCredentials
    case fileReadError(String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Missing credentials. Provide via config file (~/.config/pushover-notify/config) or --user-key/--api-token"
        case .fileReadError(let path):
            return "Could not read config file at: \(path)"
        }
    }
}

struct Credentials {
    let userKey: String
    let apiToken: String
}

struct Config {
    private static let configDir = ".config/pushover-notify"
    private static let configFile = "config"

    /// Load credentials from config file and CLI arguments (CLI args take priority)
    static func loadCredentials(userKeyArg: String?, apiTokenArg: String?) throws -> Credentials {
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

    /// Get the full path to config file
    private static func getConfigPath() -> String? {
        guard let homeDir = ProcessInfo.processInfo.environment["HOME"] else {
            return nil
        }
        return "\(homeDir)/\(configDir)/\(configFile)"
    }

    /// Parse .env style config file (KEY=VALUE format)
    private static func parseConfigFile(at path: String) throws -> [String: String] {
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
            let parts = trimmed.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                config[key] = value
            } else {
                // Malformed line - print warning but continue
                fputs("Warning: Ignoring malformed config line: \(trimmed)\n", stderr)
            }
        }

        return config
    }
}
```

**Step 2: Build to verify syntax**

Run:
```bash
swift build
```

Expected: BUILD SUCCEEDED

**Step 3: Commit Config implementation**

```bash
git add Sources/notify/Config.swift
git commit -m "feat: implement credential loading from config file and CLI args"
```

---

## Task 5: Implement CLI Interface

**Files:**
- Modify: `Sources/notify/main.swift`

**Step 1: Replace main.swift with ArgumentParser implementation**

Replace entire contents of `Sources/notify/main.swift`:

```swift
import ArgumentParser
import Foundation

@main
struct Notify: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "notify",
        abstract: "Send Pushover notifications with image attachments"
    )

    @Option(name: .long, help: "The notification message")
    var message: String

    @Option(name: .long, help: "Path to image attachment")
    var attachment: String

    @Option(name: .long, help: "Pushover user key (overrides config)")
    var userKey: String?

    @Option(name: .long, help: "Pushover API token (overrides config)")
    var apiToken: String?

    mutating func run() async throws {
        // Load credentials
        let credentials: Credentials
        do {
            credentials = try Config.loadCredentials(
                userKeyArg: userKey,
                apiTokenArg: apiToken
            )
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            throw ExitCode.failure
        }

        // Verify attachment file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: attachment) else {
            fputs("Error: Attachment file not found: \(attachment)\n", stderr)
            throw ExitCode.failure
        }

        // Send notification
        do {
            try await PushoverClient.sendNotification(
                message: message,
                attachmentPath: attachment,
                credentials: credentials
            )
            print("Notification sent successfully")
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            throw ExitCode.failure
        }
    }
}
```

**Step 2: Build (will fail - PushoverClient not implemented yet)**

Run:
```bash
swift build
```

Expected: BUILD FAILED with error about PushoverClient not being defined (this is expected)

**Step 3: Commit CLI implementation**

```bash
git add Sources/notify/main.swift
git commit -m "feat: implement CLI interface with ArgumentParser"
```

---

## Task 6: Implement Pushover API Client

**Files:**
- Create: `Sources/notify/PushoverClient.swift`

**Step 1: Create PushoverClient wrapper**

Create `Sources/notify/PushoverClient.swift`:

```swift
import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

enum PushoverError: LocalizedError {
    case fileReadError(String)
    case apiError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .fileReadError(let path):
            return "Could not read attachment file: \(path)"
        case .apiError(let message):
            return "Pushover API error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

struct PushoverClient {
    /// Send a notification with attachment to Pushover API
    static func sendNotification(
        message: String,
        attachmentPath: String,
        credentials: Credentials
    ) async throws {
        // Read attachment file data
        let fileURL = URL(fileURLWithPath: attachmentPath)
        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileURL)
        } catch {
            throw PushoverError.fileReadError(attachmentPath)
        }

        // Get filename for attachment
        let filename = fileURL.lastPathComponent

        // Create OpenAPI client
        let client = Client(
            serverURL: try Servers.server1(),
            transport: URLSessionTransport()
        )

        // Build multipart request body
        let body = Operations.sendMessage.Input.Body.multipartForm(
            .init(
                token: .init(payload: .init(
                    body: .init(credentials.apiToken)
                )),
                user: .init(payload: .init(
                    body: .init(credentials.userKey)
                )),
                message: .init(payload: .init(
                    body: .init(message)
                )),
                attachment: .init(payload: .init(
                    body: .init(fileData),
                    filename: filename
                ))
            )
        )

        // Send request
        let response: Operations.sendMessage.Output
        do {
            response = try await client.sendMessage(body: body)
        } catch {
            throw PushoverError.networkError(error)
        }

        // Handle response
        switch response {
        case .ok(let okResponse):
            // Success - parse response if needed
            switch okResponse.body {
            case .json(let responseBody):
                if responseBody.status != 1 {
                    throw PushoverError.apiError("Unexpected status: \(responseBody.status ?? 0)")
                }
            }
        case .badRequest(let errorResponse):
            // API returned error
            switch errorResponse.body {
            case .json(let errorBody):
                let errors = errorBody.errors?.joined(separator: ", ") ?? "Unknown error"
                throw PushoverError.apiError(errors)
            }
        case .undocumented(statusCode: let code, _):
            throw PushoverError.apiError("Unexpected status code: \(code)")
        }
    }
}
```

**Step 2: Build**

Run:
```bash
swift build
```

Expected: BUILD SUCCEEDED

**Step 3: Commit PushoverClient**

```bash
git add Sources/notify/PushoverClient.swift
git commit -m "feat: implement Pushover API client wrapper"
```

---

## Task 7: Create README Documentation

**Files:**
- Create: `README.md`

**Step 1: Create README with installation and usage**

Create `README.md` at package root:

```markdown
# pushover-notify

A Swift CLI tool for sending Pushover notifications with image attachments.

## Features

- Send notifications via Pushover API
- Attach images to notifications
- Credentials from config file or command-line arguments
- Simple scriptable interface

## Installation

### Build from source

```bash
git clone <repository-url>
cd pushover-notify
swift build -c release
cp .build/release/notify /usr/local/bin/notify
```

## Configuration

Create a config file at `~/.config/pushover-notify/config`:

```
USER_KEY=your-user-key-here
API_TOKEN=your-api-token-here
```

Get your credentials from [Pushover.net](https://pushover.net):
- **USER_KEY**: Your user key (found on Pushover dashboard)
- **API_TOKEN**: Your application API token (create an application first)

## Usage

### Basic usage with config file

```bash
notify --message "Hello from CLI" --attachment /path/to/image.jpg
```

### Override credentials via command-line

```bash
notify \
  --message "Deployment complete" \
  --attachment ./screenshot.png \
  --user-key YOUR_USER_KEY \
  --api-token YOUR_API_TOKEN
```

### Use in scripts

```bash
#!/bin/bash

# Take screenshot and notify
screencapture /tmp/screenshot.png
notify --message "Screenshot captured" --attachment /tmp/screenshot.png

# Check exit code
if [ $? -eq 0 ]; then
    echo "Notification sent successfully"
else
    echo "Failed to send notification" >&2
    exit 1
fi
```

## Command-Line Options

- `--message <text>` (required) - The notification message
- `--attachment <path>` (required) - Path to image file
- `--user-key <key>` (optional) - Override USER_KEY from config
- `--api-token <token>` (optional) - Override API_TOKEN from config

## Requirements

- macOS 13.0+
- Swift 5.9+

## API Reference

This tool uses the [Pushover API](https://pushover.net/api) for sending notifications. See [attachment documentation](https://pushover.net/api#attachments) for image requirements:
- Maximum size: 2.5 MB
- Supported formats: JPEG, PNG, GIF, BMP

## License

MIT License - see LICENSE file for details
```

**Step 2: Commit README**

```bash
git add README.md
git commit -m "docs: add README with installation and usage examples"
```

---

## Task 8: End-to-End Testing

**Files:**
- None (testing existing implementation)

**Step 1: Build release binary**

Run:
```bash
swift build -c release
```

Expected: BUILD SUCCEEDED

**Step 2: Test help output**

Run:
```bash
.build/release/notify --help
```

Expected: Help text showing all options (--message, --attachment, --user-key, --api-token)

**Step 3: Test missing credentials error**

Run:
```bash
.build/release/notify --message "test" --attachment /tmp/test.jpg
```

Expected: Error message "Missing credentials. Provide via config file or --user-key/--api-token"

**Step 4: Test missing file error**

Run:
```bash
.build/release/notify \
  --message "test" \
  --attachment /nonexistent/file.jpg \
  --user-key "dummy" \
  --api-token "dummy"
```

Expected: Error message "Attachment file not found: /nonexistent/file.jpg"

**Step 5: Create test config file (manual step)**

Manual action required:
1. Create directory: `mkdir -p ~/.config/pushover-notify`
2. Create file: `~/.config/pushover-notify/config`
3. Add your real credentials:
   ```
   USER_KEY=your-real-user-key
   API_TOKEN=your-real-api-token
   ```

**Step 6: Create test image (manual step)**

Manual action required:
1. Create or copy a test image to `/tmp/test.jpg`
2. Ensure it exists: `ls -lh /tmp/test.jpg`

**Step 7: Test real notification (manual step)**

Run with your credentials:
```bash
.build/release/notify \
  --message "Test notification from pushover-notify CLI" \
  --attachment /tmp/test.jpg
```

Expected:
- Output: "Notification sent successfully"
- Check your Pushover app - notification should appear with image

**Step 8: Test CLI args override config**

Run with wrong token in command (should fail):
```bash
.build/release/notify \
  --message "This should fail" \
  --attachment /tmp/test.jpg \
  --api-token "wrong-token"
```

Expected: Error message from Pushover API about invalid token (proves CLI arg overrode config)

**Step 9: Final commit**

```bash
git add -A
git commit -m "test: verify end-to-end functionality"
```

---

## Task 9: Create .gitignore

**Files:**
- Create: `.gitignore`

**Step 1: Create .gitignore for Swift**

Create `.gitignore` at package root:

```
# Swift build artifacts
.build/
*.xcodeproj
*.xcworkspace

# Swift Package Manager
.swiftpm/
Package.resolved

# macOS
.DS_Store

# IDEs
*.swp
*~
.idea/
.vscode/

# Local config (don't commit credentials)
config
*.env
```

**Step 2: Commit .gitignore**

```bash
git add .gitignore
git commit -m "chore: add .gitignore for Swift project"
```

---

## Completion Checklist

After completing all tasks, verify:

- [ ] `swift build -c release` succeeds
- [ ] `notify --help` shows all options
- [ ] Config file at `~/.config/pushover-notify/config` is read
- [ ] CLI arguments override config values
- [ ] Missing credentials show clear error
- [ ] Missing attachment file shows clear error
- [ ] Real notification sends successfully with image
- [ ] Exit code 0 on success, 1 on error
- [ ] README.md has installation and usage examples
- [ ] All changes committed to git

## Installation for Daily Use

After successful testing:

```bash
swift build -c release
sudo cp .build/release/notify /usr/local/bin/notify
```

Verify installation:
```bash
which notify
notify --help
```
