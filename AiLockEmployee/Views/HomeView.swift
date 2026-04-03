import SwiftUI
import AVFoundation

struct HomeView: View {
    @EnvironmentObject var homeViewModel: HomeViewModel
    @EnvironmentObject var supabase: SupabaseService

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Greeting
                        greetingSection

                        // Permissions card (if any missing)
                        if homeViewModel.permissionsChecked && !homeViewModel.allPermissionsGranted {
                            permissionsCard
                        }

                        // Active Session Card or Clock In options
                        if homeViewModel.activeSession != nil {
                            activeSessionCard
                        } else {
                            clockInSection
                        }

                        // Today's Summary
                        todaySummaryCard

                        // Success/Error Messages
                        if let msg = homeViewModel.successMessage {
                            messageCard(msg, color: .green)
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        homeViewModel.successMessage = nil
                                    }
                                }
                        }
                        if let msg = homeViewModel.errorMessage {
                            messageCard(msg, color: .red)
                        }
                    }
                    .padding()
                    .padding(.top, 1) // Extra inset for status bar area
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await homeViewModel.checkAndRequestPermissions()
                await homeViewModel.loadData()
            }
            .refreshable {
                await homeViewModel.checkAndRequestPermissions()
                await homeViewModel.loadData()
            }
            .sheet(isPresented: $homeViewModel.showRemoteSheet) {
                remoteClockInSheet
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text(supabase.employee?.name ?? "Employee")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 32))
                .foregroundColor(Color(hex: "3B82F6"))
        }
        .padding(.bottom, 8)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    // MARK: - Permissions Card

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Permissions Required")
                    .font(.headline)
                    .foregroundColor(.red)
            }

            if !homeViewModel.hasCameraPermission {
                permissionRow(icon: "camera.fill", label: "Camera", action: "Required for QR scanning") {
                    openSettings()
                }
            }
            if !homeViewModel.hasLocationPermission {
                permissionRow(icon: "location.fill", label: "Location", action: "Required for clock-in") {
                    openSettings()
                }
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(16)
    }

    private func permissionRow(icon: String, label: String, action: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    Text(action)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Text("Enable")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.3))
                    .foregroundColor(.red)
                    .cornerRadius(6)
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Active Session Card

    private var activeSessionCard: some View {
        VStack(spacing: 16) {
            // Mode badge — prominent for secure/focus
            modeBadge(homeViewModel.currentMode)

            // Status
            HStack {
                Circle()
                    .fill(.green)
                    .frame(width: 10, height: 10)
                Text("Clocked In")
                    .font(.headline)
                    .foregroundColor(.green)
                Spacer()
            }

            // Timer
            Text(homeViewModel.elapsedFormatted)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            // Location
            if let session = homeViewModel.activeSession {
                HStack {
                    Image(systemName: session.isRemote == true ? "wifi" : "mappin.circle.fill")
                        .foregroundColor(.gray)
                    Text(session.locationName)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                    if let time = session.clockInDate {
                        Text("Since \(DateFormatter.timeOnly.string(from: time))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }

            // Clock Out Button
            Button {
                Task { await homeViewModel.clockOut() }
            } label: {
                HStack {
                    if homeViewModel.isClockingOut {
                        ProgressView().tint(.white)
                    }
                    Image(systemName: "clock.badge.xmark")
                    Text("Clock Out")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(homeViewModel.isClockingOut)
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
    }

    // MARK: - Clock In Section

    private var clockInSection: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(.gray)
                    .frame(width: 10, height: 10)
                Text("Not Clocked In")
                    .font(.headline)
                    .foregroundColor(.gray)
                Spacer()
            }

            // Remote Clock In Button
            Button {
                homeViewModel.prepareRemoteClockIn()
            } label: {
                HStack {
                    Image(systemName: "wifi")
                    Text("Clock In (Remote)")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: "3B82F6").opacity(0.3))
                .foregroundColor(Color(hex: "3B82F6"))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "3B82F6").opacity(0.5), lineWidth: 1)
                )
            }
            .disabled(!homeViewModel.allPermissionsGranted && homeViewModel.permissionsChecked)

            Text("Or scan a location QR code in the Scan tab")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
    }

    // MARK: - Remote Clock In Sheet

    private var remoteClockInSheet: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Auto-detected location
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Location")
                                .font(.headline)
                                .foregroundColor(.white)

                            if homeViewModel.isDetectingLocation {
                                HStack {
                                    ProgressView().tint(.white)
                                    Text("Detecting location...")
                                        .foregroundColor(.gray)
                                }
                            } else if let addr = homeViewModel.remoteDetectedAddress {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(addr)
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                        if let lat = homeViewModel.remoteDetectedLat,
                                           let lng = homeViewModel.remoteDetectedLng {
                                            Text(String(format: "%.4f, %.4f", lat, lng))
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            } else {
                                // Location failed — show manual input
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Could not detect location automatically.")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)

                                    Button {
                                        Task { await homeViewModel.autoDetectLocation() }
                                    } label: {
                                        HStack {
                                            Image(systemName: "location.fill")
                                            Text("Auto Detect Location")
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(Color(hex: "3B82F6"))
                                    }

                                    TextField("", text: $homeViewModel.remoteManualAddress,
                                              prompt: Text("Enter location (e.g. Home, Coffee Shop)")
                                                .foregroundColor(.gray))
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(16)

                        // Clock In button
                        Button {
                            Task { await homeViewModel.clockInRemote() }
                        } label: {
                            HStack {
                                if homeViewModel.isClockingIn {
                                    ProgressView().tint(.white)
                                }
                                Image(systemName: "wifi")
                                Text("Clock In")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(homeViewModel.canClockInRemote ? Color(hex: "3B82F6") : Color.gray.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!homeViewModel.canClockInRemote || homeViewModel.isClockingIn)

                        if let msg = homeViewModel.errorMessage {
                            messageCard(msg, color: .red)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Remote Clock In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        homeViewModel.showRemoteSheet = false
                    }
                    .foregroundColor(.gray)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Today Summary

    private var todaySummaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Today")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(DateFormatter.dateOnly.string(from: Date()))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            HStack(spacing: 24) {
                statItem(
                    icon: "clock.fill",
                    value: formatMinutes(homeViewModel.todayTotalMinutes),
                    label: "Total"
                )
                statItem(
                    icon: "arrow.right.circle.fill",
                    value: "\(homeViewModel.todaySessions.count)",
                    label: "Sessions"
                )
            }
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
    }

    // MARK: - Helpers

    private func modeBadge(_ mode: SecurityMode) -> some View {
        HStack(spacing: 6) {
            Image(systemName: mode == .secure ? "lock.fill" : mode == .focus ? "eye.slash.fill" : "checkmark.circle.fill")
                .font(.caption)
            Text(mode == .secure ? "SECURE MODE" : mode == .focus ? "FOCUS MODE" : mode.displayName)
                .font(.caption)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(badgeBackground(mode))
        .foregroundColor(badgeForeground(mode))
        .cornerRadius(8)
    }

    private func badgeBackground(_ mode: SecurityMode) -> Color {
        switch mode {
        case .secure: return .red.opacity(0.2)
        case .focus: return Color(hex: "3B82F6").opacity(0.2)
        case .none: return .gray.opacity(0.2)
        }
    }

    private func badgeForeground(_ mode: SecurityMode) -> Color {
        switch mode {
        case .secure: return .red
        case .focus: return Color(hex: "3B82F6")
        case .none: return .gray
        }
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "3B82F6"))
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    private func messageCard(_ message: String, color: Color) -> some View {
        HStack {
            Image(systemName: color == .green ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            Text(message)
                .font(.subheadline)
            Spacer()
        }
        .foregroundColor(color)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    private func formatMinutes(_ mins: Int) -> String {
        let h = mins / 60
        let m = mins % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}
