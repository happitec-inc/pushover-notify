# AGENTS.md - Quick Reference for AI Agents

## Project Overview

**pushover-notify** is a Swift CLI tool for sending Pushover notifications with optional image attachments.

- **Language**: Swift 5.9+
- **Platform**: macOS 13.0+
- **Package Manager**: Swift Package Manager (SPM)
- **Architecture**: Single executable with OpenAPI-generated client

## Quick Start for Agents

### Build & Test
```bash
# Build release version
swift build -c release

# Run tests
.build/release/notify --help

# Test with credentials
.build/release/notify --message "Test" --user-key <key> --api-token <token>

# Test with config file (credentials at ~/.config/pushover-notify/config)
.build/release/notify --message "Test"
```

### Install for System-Wide Use
```bash
sudo cp .build/release/notify /usr/local/bin/notify
```

## Architecture Decisions

### 1. swift-openapi-generator Instead of Manual HTTP

**Why**: Pushover API requires `multipart/form-data` for attachments, which is complex to implement correctly by hand.

**Benefit**: Type-safe client code generated from OpenAPI spec, automatic handling of multipart encoding.

**Files**:
- `openapi.yaml` - Minimal Pushover API spec (only `/messages.json` endpoint)
- `openapi-generator-config.yaml` - Generator configuration
- Generated at build time: `Client.swift`, `Types.swift`, `Server.swift`

**Important**: OpenAPI files are at package root with symlinks in `Sources/notify/` (swift-openapi-generator plugin requirement).

### 2. Config File + CLI Args Pattern

**Config location**: `~/.config/pushover-notify/config`

**Format**: Simple KEY=VALUE (.env style)
```
USER_KEY=xxx
API_TOKEN=yyy
```

**Priority**: CLI args (`--user-key`, `--api-token`) override config file values.

**Security**: Config file should be `chmod 600` (owner read/write only).

### 3. Optional Attachment

**Initially**: Attachment was required (as per original design)

**Updated**: Made optional to support text-only notifications

**Implementation**: `--attachment` is `String?` in CLI, conditional multipart body construction in `PushoverClient`.

## File Structure

```
pushover-notify/
├── Package.swift                    # SPM manifest with dependencies
├── openapi.yaml                     # Pushover API spec (symlinked from Sources/notify/)
├── openapi-generator-config.yaml   # Generator config (symlinked from Sources/notify/)
├── README.md                        # User documentation
├── AGENTS.md                        # This file
├── docs/
│   └── plans/                       # Implementation plans and design docs
└── Sources/
    └── notify/
        ├── pushover_notify.swift    # CLI entry point (ArgumentParser)
        ├── Config.swift             # Credential loading from config file
        ├── PushoverClient.swift     # API client wrapper
        ├── openapi.yaml             # Symlink to ../../openapi.yaml
        └── openapi-generator-config.yaml  # Symlink to ../../openapi-generator-config.yaml
```

## Key Implementation Details

### Config.swift
- Parses .env-style config files (KEY=VALUE)
- Handles comments (#) and blank lines
- **Important**: Parser splits on FIRST `=` only (handles values with `=` in them, like base64)
- Returns empty dict if config file missing (no error - uses CLI args only)
- Throws `ConfigError.missingCredentials` if both sources fail

### PushoverClient.swift
- **Method**: `sendNotification(message:attachmentPath:credentials:)`
- **Attachment handling**: If `attachmentPath` is nil, omits attachment from multipart body
- **Multipart construction**: Build array of parts, conditionally append attachment
- **Error types**: `fileReadError`, `apiError`, `networkError`
- **Response handling**: 200 (success), 400 (error), 413 (payload too large)

### pushover_notify.swift
- ArgumentParser-based CLI
- **Required**: `--message`
- **Optional**: `--attachment`, `--user-key`, `--api-token`
- File existence check happens before API call
- All errors go to stderr with exit code 1

## Common Tasks

### Adding a New CLI Option

1. Add `@Option` property to `Notify` struct in `pushover_notify.swift`
2. Pass it to `PushoverClient.sendNotification()`
3. Update `PushoverClient` method signature
4. Add field to `openapi.yaml` multipart properties
5. Rebuild (OpenAPI generator will create new types)

### Supporting More Pushover API Parameters

Current spec is minimal (token, user, message, attachment). To add more:

1. Edit `openapi.yaml` - add parameter under `properties:`
2. Update `PushoverClient.swift` - add to multipart parts array
3. Add CLI option in `pushover_notify.swift`
4. Rebuild

Example parameters available in Pushover API:
- `title` - Notification title
- `priority` - -2 to 2 (emergency requires retry/expire)
- `sound` - Notification sound name
- `device` - Target specific device
- `url` / `url_title` - Supplementary URL
- `timestamp` - Custom timestamp
- `html` - Enable HTML formatting

### Debugging Build Issues

**Symptom**: Build fails with "cannot find openapi.yaml"
**Fix**: Ensure symlinks exist in `Sources/notify/`:
```bash
ln -sf ../../openapi.yaml Sources/notify/openapi.yaml
ln -sf ../../openapi-generator-config.yaml Sources/notify/openapi-generator-config.yaml
```

**Symptom**: Multipart body type errors
**Check**: OpenAPI generator version may have changed API. Look at generated `Types.swift` to see actual structure.

**Symptom**: "default will never be executed" warnings
**Ignore**: These are expected - defensive programming for future-proofing response handling.

## Pushover API Constraints

### Attachment Limits
- **Max size**: 2.5 MB per attachment
- **Formats**: JPEG, PNG, GIF, BMP
- **Error code**: 413 Payload Too Large if exceeded

**Agent action**: If user reports 413 errors, suggest resizing:
```bash
sips -Z 800 large-image.jpg --out smaller.jpg
```

### Rate Limits
- **Per app**: 10,000 messages/month (free tier)
- **Per user**: 10,000 messages/month
- **Burst**: No documented limit, but don't spam

### Required Credentials
- **USER_KEY**: User's Pushover key (from dashboard)
- **API_TOKEN**: Application API token (create app first)

Get credentials at: https://pushover.net

## Dependencies

### Production Dependencies
- `swift-argument-parser` (1.3.0+) - CLI argument parsing
- `swift-openapi-generator` (1.0.0+) - Code generation from OpenAPI
- `swift-openapi-runtime` (1.0.0+) - Runtime support for generated code
- `swift-openapi-urlsession` (1.0.0+) - URLSession transport

### Why These Dependencies?
- **ArgumentParser**: Apple's official CLI library, well-maintained, type-safe
- **OpenAPI stack**: Handles complex multipart/form-data without manual implementation
- **URLSession transport**: Native macOS networking, no third-party HTTP client needed

## Testing Notes

### Automated Tests (from plan)
- Help output verification
- Missing credentials error
- Missing file error
- These don't require real Pushover credentials

### Manual Tests Required
- Actual notification sending (needs real credentials)
- Image attachment upload (needs real credentials)
- Config file vs CLI args priority (needs real credentials)

### Creating Test Credentials
1. Sign up at https://pushover.net
2. Create an application (get API_TOKEN)
3. Note your USER_KEY from dashboard
4. Add to `~/.config/pushover-notify/config`

## Gotchas & Important Notes

### 1. Package.resolved in Git
**Status**: Currently excluded by .gitignore

**Rationale**: Dependency versions can vary per developer. However, for production deployment, consider committing it for reproducible builds.

### 2. OpenAPI File Locations
**Files exist in TWO places**: Package root (actual files) + `Sources/notify/` (symlinks)

**Why**: Best practice is root location, but swift-openapi-generator plugin requires them in target directory. Symlinks solve both needs.

### 3. Multipart Body Construction
**Pattern changed**: Original plan showed struct initialization, actual implementation uses array literal.

**Reason**: swift-openapi-generator API evolved. Current version uses array of enum cases.

### 4. Attachment is Optional (Updated)
**Original design**: Required attachment
**Current**: Optional attachment for text-only notifications
**Important**: Don't assume attachment exists - check for nil

### 5. Config File Parsing
**Parser splits on FIRST `=` only**: Handles tokens with `=` characters (base64, etc.)

**Bad pattern**: `parts = line.split(separator: "=")`
**Good pattern**: `line.firstIndex(of: "=")` then substring

## Version History

- **v1.0**: Initial implementation with required attachment
- **v1.1**: Made attachment optional, text-only notifications supported

## Quick Troubleshooting

| Issue | Solution |
|-------|----------|
| Build fails: "cannot find PushoverClient" | Run `swift build` - generates OpenAPI code |
| 413 Payload Too Large | Image > 2.5MB, resize with `sips -Z 800` |
| Missing credentials error | Check `~/.config/pushover-notify/config` exists and has USER_KEY, API_TOKEN |
| Invalid token/user error | Verify credentials at pushover.net dashboard |
| File not found error | Check attachment path, use absolute paths in scripts |

## Useful Commands for Agents

```bash
# Full rebuild from scratch
swift package clean && swift build -c release

# Check what's in the config file (without exposing credentials)
ls -la ~/.config/pushover-notify/config

# Test without attachment
.build/release/notify --message "Test"

# Test with attachment
.build/release/notify --message "Test" --attachment /path/to/image.jpg

# See all CLI options
.build/release/notify --help

# Check binary size
ls -lh .build/release/notify

# View commit history
git log --oneline

# See OpenAPI generated types (for debugging)
cat .build/*/Types.swift | head -100
```

## Future Enhancement Ideas

1. **Add title parameter** - Most common requested feature
2. **Add priority levels** - Support emergency notifications
3. **Validation mode** - Check file size before upload (warn if >2.5MB)
4. **Multiple attachments** - Pushover supports multiple images
5. **Stdin support** - Pipe message from other commands
6. **Environment variable support** - Alternative to config file
7. **Quiet mode** - Suppress success output for scripts
8. **Retry logic** - Auto-retry on network failures
9. **Configuration wizard** - Interactive setup of config file
10. **Image auto-resize** - Automatically resize if >2.5MB

## Agent Communication Protocol

When modifying this project:

1. **Always read existing code** before making changes
2. **Test both modes**: text-only AND with-attachment after changes
3. **Update this file** if architecture changes
4. **Commit with conventional commits**: `feat:`, `fix:`, `docs:`, `chore:`
5. **Build release version** before testing (`-c release` flag)

## Contact & Credentials

**User credentials location**: `~/.config/pushover-notify/config`
**Test image location**: `test-small.jpg` (64KB, safe for testing)
**User's Pushover account**: Has real credentials configured

---

**Last updated**: 2025-11-10

