import Foundation
import CoreLocation

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

    private let supabase = SupabaseService.shared
    private let location = LocationService.shared
    private let cache = SessionCache.shared
    private var timerTask: Task<Void, Never>?

    func loadData() async {
        isLoading = true

        // Check for active session
        activeSession = await supabase.getActiveSession()

        // If we have a cached session but server says no active session, clear cache
        if activeSession == nil && cache.hasActiveSession() {
            cache.clearSession()
        }

        // If server has active session but no cache, populate cache
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

        // Today's stats
        let stats = await supabase.getTodayStats()
        todaySessions = stats.sessions
        todayTotalMinutes = stats.totalMinutes

        isLoading = false
    }

    func processQRCode(data: String) {
        guard let jsonData = data.data(using: .utf8),
              let payload = try? JSONDecoder().decode(QRPayload.self, from: jsonData) else {
            errorMessage = "Invalid QR code. Please scan a valid AiLock location QR."
            return
        }
        scannedPayload = payload
        showClockInConfirmation = true
    }

    func clockInWithQR() async {
        guard let payload = scannedPayload else { return }
        isClockingIn = true
        errorMessage = nil

        // Get GPS
        let loc = await location.getCurrentLocation()
        let lat = loc?.coordinate.latitude
        let lng = loc?.coordinate.longitude

        // Reverse geocode
        var address: String?
        if let lat = lat, let lng = lng {
            address = await GeocodingService.reverseGeocode(lat: lat, lng: lng)
        }

        do {
            let sessionId = try await supabase.clockIn(
                locationId: payload.locationId,
                lat: lat,
                lng: lng,
                isRemote: false,
                address: address,
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
        } catch {
            errorMessage = "Clock in failed: \(error.localizedDescription)"
        }
        isClockingIn = false
    }

    func clockInRemote() async {
        isClockingIn = true
        errorMessage = nil

        // Get GPS
        let loc = await location.getCurrentLocation()
        let lat = loc?.coordinate.latitude
        let lng = loc?.coordinate.longitude

        // Reverse geocode
        var address: String?
        if let lat = lat, let lng = lng {
            address = await GeocodingService.reverseGeocode(lat: lat, lng: lng)
        }

        guard let employee = supabase.employee, let bizId = employee.businessId else {
            errorMessage = "Employee profile not found."
            isClockingIn = false
            return
        }

        do {
            // For remote, we pass the business ID as a placeholder location
            let sessionId = try await supabase.clockIn(
                locationId: bizId,
                lat: lat,
                lng: lng,
                isRemote: true,
                address: address,
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

            successMessage = "Clocked in remotely!"
            await loadData()
        } catch {
            errorMessage = "Remote clock in failed: \(error.localizedDescription)"
        }
        isClockingIn = false
    }

    func clockOut() async {
        guard let sessionId = activeSession?.id ?? cache.sessionId else {
            errorMessage = "No active session found."
            return
        }

        isClockingOut = true
        errorMessage = nil

        // Get GPS for clock out
        let loc = await location.getCurrentLocation()
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
            errorMessage = "Clock out failed: \(error.localizedDescription)"
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
