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

                // Login Form
                VStack(spacing: 20) {
                    Text("Sign in with your work credentials")
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

                    SecureField("", text: $authViewModel.password, prompt: Text("Password").foregroundColor(.gray))
                        .textFieldStyle(.plain)
                        .textContentType(.password)
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
                        Task { await authViewModel.signIn() }
                    } label: {
                        HStack {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Sign In")
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

                Spacer()
            }
            .padding(.horizontal, 32)
        }
    }
}
