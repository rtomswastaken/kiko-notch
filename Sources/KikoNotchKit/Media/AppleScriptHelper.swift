import Foundation

/// Asynchronous AppleScript helper running scripts off the main thread with NSAppleEventDescriptor returns.
/// High-performance zero-hang AppleScript executor for media session queries.
public final class AppleScriptHelper: Sendable {
    @discardableResult
    public class func execute(_ scriptText: String) async throws -> NSAppleEventDescriptor? {
        try await withCheckedThrowingContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                let script = NSAppleScript(source: scriptText)
                var error: NSDictionary?
                if let descriptor = script?.executeAndReturnError(&error) {
                    continuation.resume(returning: descriptor)
                } else if let error = error {
                    continuation.resume(throwing: NSError(domain: "AppleScriptError", code: 1, userInfo: error as? [String: Any]))
                } else {
                    continuation.resume(throwing: NSError(domain: "AppleScriptError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"]))
                }
            }
        }
    }
    
    public class func executeVoid(_ scriptText: String) async throws {
        _ = try await execute(scriptText)
    }
}
