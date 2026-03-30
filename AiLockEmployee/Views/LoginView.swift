import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 64))
                        .foregroundColor(Color(hex: "3B82F6"))

                    Text("AiLock")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Employee Attendance")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()

                if authViewModel.magicLinkSent {
                    otpView
                } else {
                    emailView
                }

                Spacer()
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Email Entry

    private var emailView: some View {
        VStack(spacing: 20) {
            Text("Sign in with your work email")
                .font(.headline)
                .foregroundColor(.white)

            TextField("", text: $authViewModel.email, prompt: Text("Email address").foregroundColor(.gray))
                .textFieldStyle(.plain)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .foregroundColor(.white)

            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button {
                Task { await authViewModel.sendMagicLink() }
            } label: {
                HStack {
                    if authViewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Send Login Code")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: "3B82F6"))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(authViewModel.isLoading)
        }
    }

    // MARK: - OTP Verification

    private var otpView: some View {
        VStack(spacing: 20) {
            Text("Enter the 6-digit code")
                .font(.headline)
                .foregroundColor(.white)

            Text("Sent to \(authViewModel.email)")
                .font(.subheadline)
                .foregroundColor(.gray)

            TextField("", text: $authViewModel.otpCode, prompt: Text("000000").foregroundColor(.gray))
                .textFieldStyle(.plain)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.title2.monospaced())
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .foregroundColor(.white)

            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button {
                Task { await authViewModel.verifyOTP() }
            } label: {
                HStack {
                    if authViewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Verify")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: "3B82F6"))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(authViewModel.isLoading)

            Button("Use different email") {
                authViewModel.resetToEmail()
            }
            .foregroundColor(Color(hex: "3B82F6"))
            .font(.subheadline)
        }
    }
}
