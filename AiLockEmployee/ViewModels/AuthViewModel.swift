import Foundation
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false

    private let supabase = SupabaseService.shared

    func signIn() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedEmail.isEmpty, trimmedEmail.contains("@") else {
            errorMessage = "Please enter a valid email address."
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Please enter your password."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await supabase.signIn(email: trimmedEmail, password: password)
            isAuthenticated = true
        } catch {
            errorMessage = ErrorHelper.message(from: error)
        }
        isLoading = false
    }

    func checkExistingSession() async {
        await supabase.refreshSession()
        isAuthenticated = supabase.isAuthenticated
    }
}
