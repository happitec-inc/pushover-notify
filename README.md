# pushover-notify

A Swift CLI tool for sending Pushover notifications with image attachments.

Full documentation, including the agentic-workflow use case, lives at <https://docs.happitec.com/pushover-notify/>.

## Features

`notify` sends a Pushover notification from the command line. It reads credentials from `~/.config/pushover-notify/config` or from `--user-key`/`--api-token` flags passed directly, and optionally attaches a JPEG, PNG, GIF, or BMP image to the notification. Exit code is 0 on success, non-zero on API or I/O error, so it composes cleanly with shell scripts.

## Installation

### Homebrew (recommended)

```bash
brew tap happitec-inc/tap
brew install pushover-notify
```

### Build from source

```bash
git clone https://github.com/happitec-inc/pushover-notify.git
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

Get your credentials from [Pushover.net](https://pushover.net). `USER_KEY` is on the Pushover dashboard. `API_TOKEN` comes from an application you create there.

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
- `--attachment <path>` (optional) - Path to image file
- `--user-key <key>` (optional) - Override USER_KEY from config
- `--api-token <token>` (optional) - Override API_TOKEN from config

## Use as a library (Linux / AWS Lambda)

`notifyCore` is exposed as a library product, so other Swift packages can send
Pushover notifications directly instead of shelling out to the `notify` CLI.

On **Linux** (for example an AWS Lambda on `provided.al2023`), don't rely on the
default `URLSessionTransport` — `URLSession`'s multipart-upload support there is
incomplete. Inject an `AsyncHTTPClientTransport` from
[swift-openapi-async-http-client](https://github.com/swift-server/swift-openapi-async-http-client)
instead. `sendNotification` takes an optional `transport` parameter for exactly this.

Add both packages to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/happitec-inc/pushover-notify", from: "0.2.0"),
    .package(url: "https://github.com/swift-server/swift-openapi-async-http-client", from: "1.0.0"),
],
targets: [
    .executableTarget(
        name: "YourLambda",
        dependencies: [
            .product(name: "notifyCore", package: "pushover-notify"),
            .product(name: "OpenAPIAsyncHTTPClient", package: "swift-openapi-async-http-client"),
        ]
    ),
]
```

Then send a notification, passing the AsyncHTTPClient transport:

```swift
import notifyCore
import OpenAPIAsyncHTTPClient

try await PushoverClient.sendNotification(
    message: "Deploy finished",
    attachmentPath: nil,   // or a path to a JPEG/PNG to attach
    credentials: Credentials(userKey: "u-your-user-key", apiToken: "a-your-app-token"),
    transport: AsyncHTTPClientTransport()
)
```

On macOS the `transport` argument can be omitted — it defaults to
`URLSessionTransport`, the same path the `notify` CLI uses.

## Requirements

- **CLI:** macOS 13.0+
- **`notifyCore` library:** macOS 13.0+ or Linux (inject `AsyncHTTPClientTransport` on Linux, as above)
- Swift 5.9+

## API Reference

This tool uses the [Pushover API](https://pushover.net/api) for sending notifications. See [attachment documentation](https://pushover.net/api#attachments) for image requirements:
- Maximum size: 2.5 MB
- Supported formats: JPEG, PNG, GIF, BMP

## License

Licensed under the MIT License — see [LICENSE](LICENSE).
