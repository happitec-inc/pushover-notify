// Helpers.swift — shared test utilities for notify CLI tests

import Foundation

/// Locate the notify binary for subprocess tests.
/// Walks up from the working directory looking for Package.swift,
/// then checks .build/debug and .build/release in that order.
func findNotifyBinary() -> String {
    let fm = FileManager.default
    var dir = URL(fileURLWithPath: fm.currentDirectoryPath)
    for _ in 0..<6 {
        if fm.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
            let debugPath = dir.appendingPathComponent(".build/debug/notify").path
            if fm.fileExists(atPath: debugPath) { return debugPath }
            let releasePath = dir.appendingPathComponent(".build/release/notify").path
            if fm.fileExists(atPath: releasePath) { return releasePath }
        }
        dir.deleteLastPathComponent()
    }
    // Fallback to PATH lookup
    return "notify"
}

/// Write `contents` to a temporary file and return its URL.
/// The caller is responsible for deleting the file after the test.
func writeTempFile(named name: String = "test-config", contents: String) throws -> URL {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(name + "-\(ProcessInfo.processInfo.processIdentifier)-\(Int.random(in: 1000...9999))")
    try contents.write(to: tmp, atomically: true, encoding: .utf8)
    return tmp
}

/// Run the notify binary with the given arguments, returning (stdout+stderr, exit code).
func runNotify(args: [String], binaryPath: String) throws -> (output: String, exitCode: Int32) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: binaryPath)
    process.arguments = args

    // Suppress any accidental config file reads by overriding HOME to /tmp
    var env = ProcessInfo.processInfo.environment
    env["HOME"] = NSTemporaryDirectory()
    process.environment = env

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    return (output, process.terminationStatus)
}
