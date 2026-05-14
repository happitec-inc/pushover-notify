# Pushover Notify CLI Tool - Design Document

**Date:** 2025-11-08
**Status:** Approved

## Overview

A Swift-based CLI tool that sends Pushover notifications with image attachments. Designed for scriptability, using swift-openapi-generator for type-safe API interactions.

## Requirements

### Core Functionality
- Send notifications via Pushover API with image attachments
- CLI interface: `notify --message "text" --attachment /path/to/image.jpg`
- Support only message and attachment parameters (minimal scope)

### Credential Management
- Support config file at `~/.config/pushover-notify/config`
- Support command-line arguments (--user-key, --api-token)
- Priority: CLI args override config file values

### Output & Error Handling
- Success: Print "Notification sent successfully" to stdout
- Errors: Print descriptive messages to stderr, exit code 1
- File validation: Check file exists only (let API handle format/size)

## Architecture

### Approach
Single executable target using swift-openapi-generator for API client generation. This provides:
- Type-safe API interactions
- Automatic multipart/form-data handling
- OpenAPI spec serves as API documentation
- Minimal manual HTTP boilerplate

### Package Structure
```
pushover-notify/
├── Package.swift
├── README.md (installation & usage examples)
├── openapi.yaml (Pushover API spec - messages endpoint only)
├── openapi-generator-config.yaml (generator configuration)
└── Sources/
    └── notify/
        ├── main.swift (entry point with ArgumentParser)
        ├── Config.swift (config file loading)
        └── PushoverClient.swift (wrapper around generated client)
```

### Dependencies
- `swift-argument-parser` - CLI argument parsing
- `swift-openapi-generator` - generates client from OpenAPI spec
- `swift-openapi-runtime` - runtime support for generated code
- `swift-openapi-urlsession` - URLSession transport implementation

### Build Process
1. swift-openapi-generator plugin runs at build time
2. Reads `openapi.yaml` and generates Swift client code
3. Generated code compiles with source files
4. Single executable binary produced

## Component Design

### 1. Configuration Loading (Config.swift)

**Config File Format (.env style):**
```
USER_KEY=your-user-key-here
API_TOKEN=your-api-token-here
```

**Location:** `~/.config/pushover-notify/config`

**Loading Logic:**
1. Attempt to load and parse config file (simple KEY=VALUE parser)
2. Override values with CLI arguments if provided
3. Validate both credentials are present
4. Exit with error if credentials missing after all sources

**Error Handling:**
- Config file missing: OK, use only CLI args
- Malformed lines: Print warning, continue with parseable values
- Missing credentials: Exit with clear error message

### 2. CLI Interface (main.swift)

**Command Structure:**
```swift
@main
struct Notify: AsyncParsableCommand {
    @Option(name: .long, help: "The notification message")
    var message: String

    @Option(name: .long, help: "Path to image attachment")
    var attachment: String

    @Option(name: .long, help: "Pushover user key (overrides config)")
    var userKey: String?

    @Option(name: .long, help: "Pushover API token (overrides config)")
    var apiToken: String?
}
```

**Arguments:**
- `--message` (required) - Notification message text
- `--attachment` (required) - Path to image file
- `--user-key` (optional) - Override config USER_KEY
- `--api-token` (optional) - Override config API_TOKEN

**Validation:**
- ArgumentParser enforces required arguments
- File existence checked in run() method
- Exit codes: 0 = success, 1 = error

### 3. OpenAPI Specification

**openapi.yaml - Minimal Spec:**
- Single POST endpoint: `https://api.pushover.net/1/messages.json`
- Request: multipart/form-data with fields:
  - `token` (string, required) - API token
  - `user` (string, required) - User key
  - `message` (string, required) - Message text
  - `attachment` (binary, optional) - Image file data
- Response 200: JSON with status field
- Response 400: JSON with error details

**openapi-generator-config.yaml:**
```yaml
generate:
  - types
  - client
```

### 4. API Client Wrapper (PushoverClient.swift)

**Responsibilities:**
1. Load credentials from config + CLI args
2. Validate file exists and is readable
3. Read file data from disk
4. Construct request using generated types
5. Call generated client method
6. Handle response/errors

**Flow:**
```
PushoverClient.send(message, attachmentPath, credentials)
  → Read file data
  → Build multipart request (via generated types)
  → Call generated client
  → Return success/failure
```

Generated client handles all multipart/form-data encoding.

### 5. Error Handling

**Error Categories:**
1. **Configuration** - Missing credentials, can't read config
2. **File** - Attachment not found or unreadable
3. **API** - Invalid credentials, rate limits, validation errors
4. **Network** - Connection failures, timeouts

**Error Messages (stderr):**
- `Error: Attachment file not found: /path/to/file.jpg`
- `Error: Missing credentials. Provide via config file or --user-key/--api-token`
- `Error: Pushover API error: <api error message>`
- `Error: Network error: <network error details>`

**Implementation:**
- Custom error types for each category
- Catch errors at top level in run()
- Format with clear, actionable messages
- Always exit code 1 on error

## Data Flow

```
1. User runs: notify --message "Hello" --attachment image.jpg
2. ArgumentParser validates required args
3. Config.load() reads ~/.config/pushover-notify/config
4. CLI args override config values
5. Validate credentials present
6. Check attachment file exists
7. PushoverClient reads file data
8. Generated client constructs multipart request
9. HTTP POST to Pushover API
10. Success → print confirmation, exit 0
11. Error → print to stderr, exit 1
```

## Success Criteria

- Binary builds successfully with swift build
- Can send notification with image from command line
- Credentials load from config file
- CLI args override config file
- Clear error messages for all failure modes
- Exit codes correct (0 = success, 1 = error)
- Works in shell scripts (other tools can call it)

## Future Enhancements (Out of Scope)

- Support for additional Pushover parameters (title, priority, sound, etc.)
- Environment variable support for credentials
- Image format/size validation
- Multiple attachment support
- Interactive config setup wizard
- Progress indication for large files
