import Foundation

/// Persists active session state to UserDefaults for restore on app restart.
final class SessionCache {
    static let shared = SessionCache()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let sessionId = "ailock_active_session_id"
        static let locationId = "ailock_active_location_id"
        static let locationName = "ailock_active_location_name"
        static let securityMode = "ailock_active_security_mode"
        static let clockInAt = "ailock_active_clock_in_at"
        static let isRemote = "ailock_active_is_remote"
    }

    func saveActiveSession(
        sessionId: String,
        locationId: String?,
        locationName: String,
        securityMode: String,
        clockInAt: Date,
        isRemote: Bool
    ) {
        defaults.set(sessionId, forKey: Keys.sessionId)
        defaults.set(locationId, forKey: Keys.locationId)
        defaults.set(locationName, forKey: Keys.locationName)
        defaults.set(securityMode, forKey: Keys.securityMode)
        defaults.set(clockInAt.timeIntervalSince1970, forKey: Keys.clockInAt)
        defaults.set(isRemote, forKey: Keys.isRemote)
    }

    func hasActiveSession() -> Bool {
        defaults.string(forKey: Keys.sessionId) != nil
    }

    var sessionId: String? { defaults.string(forKey: Keys.sessionId) }
    var locationId: String? { defaults.string(forKey: Keys.locationId) }
    var locationName: String? { defaults.string(forKey: Keys.locationName) }
    var securityMode: SecurityMode {
        SecurityMode(rawValue: defaults.string(forKey: Keys.securityMode) ?? "none") ?? .none
    }
    var clockInAt: Date? {
        let ts = defaults.double(forKey: Keys.clockInAt)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }
    var isRemote: Bool { defaults.bool(forKey: Keys.isRemote) }

    func clearSession() {
        defaults.removeObject(forKey: Keys.sessionId)
        defaults.removeObject(forKey: Keys.locationId)
        defaults.removeObject(forKey: Keys.locationName)
        defaults.removeObject(forKey: Keys.securityMode)
        defaults.removeObject(forKey: Keys.clockInAt)
        defaults.removeObject(forKey: Keys.isRemote)
    }
}
