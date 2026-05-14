import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

// Import generated types
typealias MultipartBody = OpenAPIRuntime.MultipartBody

public enum PushoverError: LocalizedError {
    case fileReadError(String)
    case apiError(String)
    case networkError(Error)

    public var errorDescription: String? {
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

public struct PushoverClient {
    /// Send a notification with optional attachment to Pushover API
    public static func sendNotification(
        message: String,
        attachmentPath: String?,
        credentials: Credentials
    ) async throws {
        // Create OpenAPI client
        let client = Client(
            serverURL: try Servers.Server1.url(),
            transport: URLSessionTransport()
        )

        // Build multipart request body as array of parts
        var multipartParts: [Operations.sendMessage.Input.Body.multipartFormPayload] = [
            .token(.init(payload: .init(
                body: .init(credentials.apiToken)
            ))),
            .user(.init(payload: .init(
                body: .init(credentials.userKey)
            ))),
            .message(.init(payload: .init(
                body: .init(message)
            )))
        ]

        // Add attachment if provided
        if let attachmentPath = attachmentPath {
            let fileURL = URL(fileURLWithPath: attachmentPath)
            let fileData: Data
            do {
                fileData = try Data(contentsOf: fileURL)
            } catch {
                throw PushoverError.fileReadError(attachmentPath)
            }

            let filename = fileURL.lastPathComponent
            multipartParts.append(
                .attachment(.init(payload: .init(
                    body: .init(fileData)
                ), filename: filename))
            )
        }

        let body = Operations.sendMessage.Input.Body.multipartForm(MultipartBody(multipartParts))

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
            default:
                throw PushoverError.apiError("Unexpected response format")
            }
        case .badRequest(let errorResponse):
            // API returned error
            switch errorResponse.body {
            case .json(let errorBody):
                let errors = errorBody.errors?.joined(separator: ", ") ?? "Unknown error"
                throw PushoverError.apiError(errors)
            default:
                throw PushoverError.apiError("Invalid request format")
            }
        case .undocumented(statusCode: let code, _):
            throw PushoverError.apiError("Unexpected status code: \(code)")
        }
    }
}
