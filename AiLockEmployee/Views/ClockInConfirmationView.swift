import SwiftUI

struct ClockInConfirmationView: View {
    let payload: QRPayload
    @EnvironmentObject var homeViewModel: HomeViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Mode Icon
            Image(systemName: modeIcon)
                .font(.system(size: 64))
                .foregroundColor(modeColor)

            // Title
            Text("Clock In?")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            // Mode Badge
            HStack(spacing: 8) {
                Image(systemName: modeIcon)
                    .font(.subheadline)
                Text(payload.securityMode.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(modeColor.opacity(0.2))
            .foregroundColor(modeColor)
            .cornerRadius(12)

            // Mode Description
            Text(payload.securityMode.description)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if payload.securityMode != .none {
                // FamilyControls notice
                Text("App blocking will be available in a future update.")
                    .font(.caption)
                    .foregroundColor(.yellow.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button {
                    Task { await homeViewModel.clockInWithQR() }
                } label: {
                    HStack {
                        if homeViewModel.isClockingIn {
                            ProgressView().tint(.white)
                        }
                        Text("Confirm Clock In")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(modeColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(homeViewModel.isClockingIn)

                Button("Cancel") {
                    homeViewModel.showClockInConfirmation = false
                    homeViewModel.scannedPayload = nil
                }
                .foregroundColor(.gray)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    private var modeIcon: String {
        switch payload.securityMode {
        case .secure: return "lock.fill"
        case .focus: return "eye.slash.fill"
        case .none: return "checkmark.circle.fill"
        }
    }

    private var modeColor: Color {
        switch payload.securityMode {
        case .secure: return .red
        case .focus: return Color(hex: "3B82F6")
        case .none: return .green
        }
    }
}
