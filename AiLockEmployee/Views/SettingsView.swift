import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var supabase: SupabaseService
    @State private var displayName = ""
    @State private var isSaving = false
    @State private var showLogoutConfirm = false
    @State private var savedMessage: String?
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isChangingPassword = false
    @State private var passwordMessage: String?
    @State private var passwordMessageIsError = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                List {
                    // Profile Section
                    Section {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "3B82F6").opacity(0.2))
                                    .frame(width: 56, height: 56)
                                Text(initials)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(hex: "3B82F6"))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(supabase.employee?.name ?? "Employee")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(supabase.employee?.email ?? "")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.leading, 8)
                        }
                        .listRowBackground(Color.white.opacity(0.06))
                        .padding(.vertical, 4)
                    }

                    // Name
                    Section("Display Name") {
                        TextField("", text: $displayName, prompt: Text("Your name").foregroundColor(.gray))
                            .foregroundColor(.white)
                            .listRowBackground(Color.white.opacity(0.06))

                        Button {
                            Task { await saveName() }
                        } label: {
                            HStack {
                                if isSaving {
                                    ProgressView().tint(Color(hex: "3B82F6"))
                                }
                                Text("Save Name")
                            }
                            .foregroundColor(Color(hex: "3B82F6"))
                        }
                        .listRowBackground(Color.white.opacity(0.06))
                        .disabled(isSaving || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    if let msg = savedMessage {
                        Section {
                            Text(msg)
                                .foregroundColor(.green)
                                .font(.caption)
                                .listRowBackground(Color.clear)
                        }
                    }

                    // Info Section
                    Section("About") {
                        infoRow("Employee ID", value: supabase.employee?.employeeCode ?? "—")
                        infoRow("App Version", value: "1.0.0")
                        infoRow("Security Modes", value: "Secure, Focus, None")
                    }

                    // FamilyControls Status
                    Section("App Blocking") {
                        HStack {
                            Image(systemName: "shield.slash")
                                .foregroundColor(.yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Not Available")
                                    .foregroundColor(.white)
                                Text("FamilyControls entitlement pending. Mode badges are displayed but app blocking is not yet active.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.06))
                    }

                    // Change Password
                    Section("Change Password") {
                        SecureField("", text: $currentPassword, prompt: Text("Current password").foregroundColor(.gray))
                            .foregroundColor(.white)
                            .textContentType(.password)
                            .listRowBackground(Color.white.opacity(0.06))

                        SecureField("", text: $newPassword, prompt: Text("New password").foregroundColor(.gray))
                            .foregroundColor(.white)
                            .textContentType(.newPassword)
                            .listRowBackground(Color.white.opacity(0.06))

                        SecureField("", text: $confirmPassword, prompt: Text("Confirm new password").foregroundColor(.gray))
                            .foregroundColor(.white)
                            .textContentType(.newPassword)
                            .listRowBackground(Color.white.opacity(0.06))

                        Button {
                            Task { await changePassword() }
                        } label: {
                            HStack {
                                if isChangingPassword {
                                    ProgressView().tint(Color(hex: "3B82F6"))
                                }
                                Text("Update Password")
                            }
                            .foregroundColor(Color(hex: "3B82F6"))
                        }
                        .listRowBackground(Color.white.opacity(0.06))
                        .disabled(isChangingPassword || newPassword.isEmpty || currentPassword.isEmpty)

                        if let msg = passwordMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(passwordMessageIsError ? .red : .green)
                                .listRowBackground(Color.clear)
                        }
                    }

                    // Logout
                    Section {
                        Button(role: .destructive) {
                            showLogoutConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                            .foregroundColor(.red)
                        }
                        .listRowBackground(Color.white.opacity(0.06))
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                displayName = supabase.employee?.name ?? ""
            }
            .alert("Sign Out?", isPresented: $showLogoutConfirm) {
                Button("Sign Out", role: .destructive) {
                    Task {
                        SessionCache.shared.clearSession()
                        await supabase.signOut()
                        authViewModel.isAuthenticated = false
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You will need to sign in again with your work email.")
            }
        }
        .navigationViewStyle(.stack)
    }

    private var initials: String {
        let name = supabase.employee?.name ?? "?"
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .font(.subheadline)
        }
        .listRowBackground(Color.white.opacity(0.06))
    }

    private func changePassword() async {
        guard newPassword == confirmPassword else {
            passwordMessage = "Passwords don't match."
            passwordMessageIsError = true
            return
        }
        guard newPassword.count >= 6 else {
            passwordMessage = "Password must be at least 6 characters."
            passwordMessageIsError = true
            return
        }

        isChangingPassword = true
        passwordMessage = nil

        // Verify current password by re-authenticating
        do {
            let email = supabase.employee?.email ?? supabase.currentUser?.email ?? ""
            try await supabase.signIn(email: email, password: currentPassword)
        } catch {
            passwordMessage = "Current password is incorrect."
            passwordMessageIsError = true
            isChangingPassword = false
            return
        }

        do {
            try await supabase.changePassword(newPassword: newPassword)
            passwordMessage = "Password updated!"
            passwordMessageIsError = false
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { passwordMessage = nil }
        } catch {
            passwordMessage = "Failed to update password."
            passwordMessageIsError = true
        }
        isChangingPassword = false
    }

    private func saveName() async {
        isSaving = true
        do {
            try await supabase.updateEmployeeName(displayName.trimmingCharacters(in: .whitespaces))
            savedMessage = "Name updated!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { savedMessage = nil }
        } catch {
            savedMessage = "Failed to save."
        }
        isSaving = false
    }
}
