import Foundation

/// Converts raw Supabase/network errors into user-friendly messages.
/// Never exposes URLs, headers, or auth tokens to the user.
enum ErrorHelper {

    static func message(from error: Error) -> String {
        let raw = error.localizedDescription.lowercased()

        // Auth errors
        if raw.contains("invalid login credentials") || raw.contains("invalid_credentials") {
            return "Invalid email or password. Please try again."
        }
        if raw.contains("email not confirmed") {
            return "Your email has not been confirmed."
        }
        if raw.contains("too many requests") || raw.contains("rate limit") || raw.contains("429") {
            return "Too many attempts. Please wait a moment and try again."
        }
        if raw.contains("user not found") || raw.contains("no user found") {
            return "Account not found."
        }

        // Password change
        if raw.contains("same_password") || raw.contains("same password") {
            return "New password must be different from your current password."
        }
        if raw.contains("weak_password") || raw.contains("weak password") {
            return "Password is too weak. Use at least 6 characters."
        }

        // Session / clock errors
        if raw.contains("session is not active") || raw.contains("not active") {
            return "session_not_active" // sentinel for silent handling
        }

        // Network
        if raw.contains("network") || raw.contains("internet") || raw.contains("offline") ||
           (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorNotConnectedToInternet {
            return "No internet connection."
        }
        if raw.contains("timed out") || raw.contains("timeout") ||
           (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorTimedOut {
            return "Connection timed out. Please try again."
        }

        // Fallback — generic, never raw
        return "Something went wrong. Please try again."
    }
}
