import Foundation
import CoreLocation
import AVFoundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var activeSession: AttendanceSession?
    @Published var todaySessions: [AttendanceSession] = []
    @Published var todayTotalMinutes: Int = 0
    @Published var isLoading = false
    @Published var isClockingIn = false
    @Published var isClockingOut = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var elapsedSeconds: Int = 0

    // QR scan result
    @Published var scannedPayload: QRPayload?
    @Published var showClockInConfirmation = false

    // Permissions
    @Published var hasCameraPermission = false
    @Published var hasLocationPermission = false
    @Published var permissionsChecked = false

    // Remote clock-in — manual location fallback
    @Published var remoteDetectedAddress: String?
    @Published var remoteDetectedLat: Double?
    @Published var remoteDetectedLng: Double?
    @Published var remoteManualAddress: String = ""
    @Published var isDetectingLocation = false
    @Published var showRemoteSheet = false

    private let supabase = SupabaseService.shared
    private let location = LocationService.shared
    private let cache = SessionCache.shared
    private var timerTask: Task<Void, Never>?

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true

        activeSession = await supabase.getActiveSession()

        if activeSession == nil && cache.hasActiveSession() {
            cache.clearSession()
        }

        if let session = activeSession, let sid = session.id {
            cache.saveActiveSession(
                sessionId: sid,
                locationId: session.locationId,
                locationName: session.locationName,
                securityMode: session.securityMode ?? "none",
                clockInAt: session.clockInDate ?? Date(),
                isRemote: session.isRemote ?? false
            )
            startTimer()
        }

        let stats = await supabase.getTodayStats()
        todaySessions = stats.sessions
        todayTotalMinutes = stats.totalMinutes

        isLoading = false
    }

    // MARK: - Permissions

    func checkAndRequestPermissions() async {
        // Camera
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasCameraPermission = true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            hasCameraPermission = granted
        default:
            hasCameraPermission = false
        }

        // Location (request after camera)
        let locStatus = location.authorizationStatus
        switch locStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            hasLocationPermission = true
        case .notDetermined:
            location.requestPermission()
            // Wait briefly for the delegate callback
            try? await Task.sleep(nanoseconds: 500_000_000)
            let updated = location.authorizationStatus
            hasLocationPermission = (updated == .authorizedWhenInUse || updated == .authorizedAlways)
        default:
            hasLocationPermission = false
        }

        permissionsChecked = true
    }

    var allPermissionsGranted: Bool {
        hasCameraPermission && hasLocationPermission
    }

    // MARK: - QR Code

    func processQRCode(data: String) {
        guard let jsonData = data.data(using: .utf8),
              let payload = try? QRPayload.decode(from: jsonData) else {
            errorMessage = "Invalid QR code. Please scan a valid AiLock location QR."
            return
        }
        scannedPayload = payload
        showClockInConfirmation = true
    }

    // MARK: - QR Clock In (Fast)

    func clockInWithQR() async {
        guard let payload = scannedPayload else { return }
        isClockingIn = true
        errorMessage = nil

        // Use last known location instantly — no GPS wait
        let loc = location.getLastKnown()
        let lat = loc?.coordinate.latitude
        let lng = loc?.coordinate.longitude

        // If location permission not granted, skip — QR locationId is proof of presence
        if location.authorizationStatus == .notDetermined {
            location.requestPermission()
        }

        do {
            let sessionId = try await supabase.clockIn(
                locationId: payload.locationId,
                lat: lat,
                lng: lng,
                isRemote: false,
                address: nil, // Will be updated in background
                securityMode: payload.mode
            )

            cache.saveActiveSession(
                sessionId: sessionId,
                locationId: payload.locationId,
                locationName: "Location",
                securityMode: payload.mode,
                clockInAt: Date(),
                isRemote: false
            )

            showClockInConfirmation = false
            scannedPayload = nil
            successMessage = "Clocked in successfully!"
            await loadData()

            // Update address in background
            if let lat = lat, let lng = lng {
                Task {
                    if let address = await GeocodingService.reverseGeocode(lat: lat, lng: lng) {
                        try? await supabase.client.from("attendance_sessions")
                            .update(["clock_in_address": address])
                            .eq("id", value: sessionId)
                            .execute()
                    }
                }
            }
        } catch {
            errorMessage = ErrorHelper.message(from: error)
        }
        isClockingIn = false
    }

    // MARK: - Remote Clock In

    func prepareRemoteClockIn() {
        remoteDetectedAddress = nil
        remoteDetectedLat = nil
        remoteDetectedLng = nil
        remoteManualAddress = ""
        showRemoteSheet = true
        Task { await autoDetectLocation() }
    }

    func autoDetectLocation() async {
        isDetectingLocation = true
        remoteDetectedAddress = nil
        remoteDetectedLat = nil
        remoteDetectedLng = nil

        // Request permission if needed
        if location.authorizationStatus == .notDetermined {
            location.requestPermission()
            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        let loc = await location.getCurrentLocation()
        if let loc = loc {
            let lat = loc.coordinate.latitude
            let lng = loc.coordinate.longitude
            remoteDetectedLat = lat
            remoteDetectedLng = lng
            if let address = await GeocodingService.reverseGeocode(lat: lat, lng: lng) {
                remoteDetectedAddress = address
            } else {
                remoteDetectedAddress = String(format: "%.4f, %.4f", lat, lng)
            }
        }
        isDetectingLocation = false
    }

    var canClockInRemote: Bool {
        remoteDetectedAddress != nil || !remoteManualAddress.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func clockInRemote() async {
        isClockingIn = true
        errorMessage = nil

        guard let employee = supabase.employee, let bizId = employee.businessId else {
            errorMessage = "Employee profile not found."
            isClockingIn = false
            return
        }

        let lat = remoteDetectedLat
        let lng = remoteDetectedLng
        let address = remoteDetectedAddress ?? remoteManualAddress.trimmingCharacters(in: .whitespaces)

        do {
            let sessionId = try await supabase.clockIn(
                locationId: bizId,
                lat: lat,
                lng: lng,
                isRemote: true,
                address: address.isEmpty ? nil : address,
                securityMode: "none"
            )

            cache.saveActiveSession(
                sessionId: sessionId,
                locationId: nil,
                locationName: "Remote",
                securityMode: "none",
                clockInAt: Date(),
                isRemote: true
            )

            showRemoteSheet = false
            successMessage = "Clocked in remotely!"
            await loadData()
        } catch {
            errorMessage = ErrorHelper.message(from: error)
        }
        isClockingIn = false
    }

    // MARK: - Clock Out

    func clockOut() async {
        guard let sessionId = activeSession?.id ?? cache.sessionId else {
            errorMessage = "No active session found."
            return
        }

        isClockingOut = true
        errorMessage = nil

        // Use last known location (instant) instead of fresh GPS fix
        let loc = location.getLastKnown()
        let lat = loc?.coordinate.latitude
        let lng = loc?.coordinate.longitude

        var address: String?
        if let lat = lat, let lng = lng {
            address = await GeocodingService.reverseGeocode(lat: lat, lng: lng)
        }

        do {
            let totalMins = try await supabase.clockOut(
                sessionId: sessionId,
                lat: lat,
                lng: lng,
                address: address
            )

            stopTimer()
            cache.clearSession()
            activeSession = nil

            let h = totalMins / 60
            let m = totalMins % 60
            successMessage = "Clocked out! Total: \(h > 0 ? "\(h)h " : "")\(m)m"
            await loadData()
        } catch {
            let msg = ErrorHelper.message(from: error)
            if msg == "session_not_active" {
                // Session already ended server-side — silently refresh
                stopTimer()
                cache.clearSession()
                activeSession = nil
                await loadData()
            } else {
                errorMessage = msg
            }
        }
        isClockingOut = false
    }

    // MARK: - Timer

    func startTimer() {
        stopTimer()
        timerTask = Task {
            while !Task.isCancelled {
                if let clockIn = activeSession?.clockInDate ?? cache.clockInAt {
                    elapsedSeconds = Int(Date().timeIntervalSince(clockIn))
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
        elapsedSeconds = 0
    }

    var elapsedFormatted: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var currentMode: SecurityMode {
        activeSession?.mode ?? cache.securityMode
    }
}
