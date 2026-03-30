import Foundation
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var otpCode = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var magicLinkSent = false
    @Published var isAuthenticated = false

    private let supabase = SupabaseService.shared

    func sendMagicLink() async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, trimmed.contains("@") else {
            errorMessage = "Please enter a valid email address."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await supabase.sendMagicLink(email: trimmed)
            magicLinkSent = true
        } catch {
            errorMessage = "Failed to send login code. Please try again."
        }
        isLoading = false
    }

    func verifyOTP() async {
        let trimmed = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 6 else {
            errorMessage = "Please enter the 6-digit code."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await supabase.verifyOTP(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                token: trimmed
            )
            isAuthenticated = true
        } catch {
            errorMessage = "Invalid code. Please try again."
        }
        isLoading = false
    }

    func checkExistingSession() async {
        await supabase.refreshSession()
        isAuthenticated = supabase.isAuthenticated
    }

    func resetToEmail() {
        magicLinkSent = false
        otpCode = ""
        errorMessage = nil
    }
}
