import ArgumentParser
import Foundation
import notifyCore

@main
struct Notify: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "notify",
        abstract: "Send Pushover notifications with optional image attachments"
    )

    @Option(name: .long, help: "The notification message")
    var message: String

    @Option(name: .long, help: "Path to image attachment (optional)")
    var attachment: String?

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

        // Verify attachment file exists (if provided)
        if let attachmentPath = attachment {
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: attachmentPath) else {
                fputs("Error: Attachment file not found: \(attachmentPath)\n", stderr)
                throw ExitCode.failure
            }
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
