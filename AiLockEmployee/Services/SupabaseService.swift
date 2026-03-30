import Foundation
import Supabase
import AuthenticationServices

@MainActor
final class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    let client: SupabaseClient
    @Published var currentUser: User?
    @Published var employee: Employee?

    private init() {
        guard let secrets = SupabaseService.loadSecrets() else {
            fatalError("Missing Secrets.plist — copy Secrets.example.plist and fill in credentials.")
        }
        guard let urlString = secrets["SUPABASE_URL"] as? String,
              let url = URL(string: urlString),
              let key = secrets["SUPABASE_ANON_KEY"] as? String else {
            fatalError("Secrets.plist must contain SUPABASE_URL and SUPABASE_ANON_KEY")
        }
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }

    private static func loadSecrets() -> [String: Any]? {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return nil
        }
        return dict
    }

    // MARK: - Auth

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
        await refreshSession()
    }

    func changePassword(newPassword: String) async throws {
        try await client.auth.update(user: UserAttributes(password: newPassword))
    }

    func refreshSession() async {
        do {
            let session = try await client.auth.session
            currentUser = session.user
            await fetchEmployee()
        } catch {
            currentUser = nil
            employee = nil
        }
    }

    func signOut() async {
        try? await client.auth.signOut()
        currentUser = nil
        employee = nil
    }

    var isAuthenticated: Bool {
        currentUser != nil
    }

    // MARK: - Employee

    func fetchEmployee() async {
        guard let userId = currentUser?.id else { return }
        do {
            let result: Employee = try await client.from("employees")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            employee = result
        } catch {
            print("Failed to fetch employee: \(error)")
        }
    }

    func updateEmployeeName(_ name: String) async throws {
        guard let userId = currentUser?.id else { return }
        try await client.from("employees")
            .update(["name": name])
            .eq("id", value: userId.uuidString)
            .execute()
        await fetchEmployee()
    }

    // MARK: - Clock In

    func clockIn(
        locationId: String,
        lat: Double?,
        lng: Double?,
        isRemote: Bool,
        address: String?,
        securityMode: String?
    ) async throws -> String {
        guard let employeeId = currentUser?.id.uuidString else {
            throw AiLockError.notAuthenticated
        }

        struct NewSession: Codable {
            let employee_id: String
            let location_id: String?
            let clock_in_lat: Double?
            let clock_in_lng: Double?
            let clock_in_address: String?
            let method: String
            let is_remote: Bool
            let security_mode: String?
            let status: String
        }

        let newSession = NewSession(
            employee_id: employeeId,
            location_id: isRemote ? nil : locationId,
            clock_in_lat: lat,
            clock_in_lng: lng,
            clock_in_address: address,
            method: isRemote ? "remote" : "qr",
            is_remote: isRemote,
            security_mode: securityMode,
            status: "active"
        )

        struct InsertResult: Codable {
            let id: String
        }

        let result: InsertResult = try await client.from("attendance_sessions")
            .insert(newSession)
            .select("id")
            .single()
            .execute()
            .value

        return result.id
    }

    // MARK: - Clock Out

    func clockOut(sessionId: String, lat: Double?, lng: Double?, address: String?) async throws -> Int {
        let now = ISO8601DateFormatter().string(from: Date())

        struct UpdatePayload: Codable {
            let clock_out_at: String
            let clock_out_lat: Double?
            let clock_out_lng: Double?
            let clock_out_address: String?
            let status: String
        }

        let payload = UpdatePayload(
            clock_out_at: now,
            clock_out_lat: lat,
            clock_out_lng: lng,
            clock_out_address: address,
            status: "completed"
        )

        try await client.from("attendance_sessions")
            .update(payload)
            .eq("id", value: sessionId)
            .execute()

        struct SessionResult: Codable {
            let clock_in_at: String?
            let clock_out_at: String?
            let total_minutes: Int?
        }
        let session: SessionResult = try await client.from("attendance_sessions")
            .select("clock_in_at,clock_out_at,total_minutes")
            .eq("id", value: sessionId)
            .single()
            .execute()
            .value

        if let mins = session.total_minutes { return mins }

        if let inStr = session.clock_in_at, let outStr = session.clock_out_at,
           let inDate = ISO8601DateFormatter().date(from: inStr) ?? DateFormatter.supabase.date(from: inStr),
           let outDate = ISO8601DateFormatter().date(from: outStr) ?? DateFormatter.supabase.date(from: outStr) {
            return Int(outDate.timeIntervalSince(inDate) / 60)
        }
        return 0
    }

    // MARK: - Active Session

    func getActiveSession() async -> AttendanceSession? {
        guard let userId = currentUser?.id.uuidString else { return nil }
        do {
            let sessions: [AttendanceSession] = try await client.from("attendance_sessions")
                .select("*, location:locations(name)")
                .eq("employee_id", value: userId)
                .eq("status", value: "active")
                .order("clock_in_at", ascending: false)
                .limit(1)
                .execute()
                .value
            return sessions.first
        } catch {
            print("Failed to fetch active session: \(error)")
            return nil
        }
    }

    // MARK: - Session History

    func getSessionHistory(limit: Int = 50) async -> [AttendanceSession] {
        guard let userId = currentUser?.id.uuidString else { return [] }
        do {
            let sessions: [AttendanceSession] = try await client.from("attendance_sessions")
                .select("*, location:locations(name)")
                .eq("employee_id", value: userId)
                .order("clock_in_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return sessions
        } catch {
            print("Failed to fetch history: \(error)")
            return []
        }
    }

    // MARK: - Today's Stats

    func getTodayStats() async -> (sessions: [AttendanceSession], totalMinutes: Int) {
        guard let userId = currentUser?.id.uuidString else { return ([], 0) }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let isoFormatter = ISO8601DateFormatter()

        do {
            let sessions: [AttendanceSession] = try await client.from("attendance_sessions")
                .select("*, location:locations(name)")
                .eq("employee_id", value: userId)
                .gte("clock_in_at", value: isoFormatter.string(from: startOfDay))
                .order("clock_in_at", ascending: false)
                .execute()
                .value

            var totalMins = 0
            for session in sessions {
                if let mins = session.totalMinutes {
                    totalMins += mins
                } else if let start = session.clockInDate {
                    let end = session.clockOutDate ?? Date()
                    totalMins += Int(end.timeIntervalSince(start) / 60)
                }
            }
            return (sessions, totalMins)
        } catch {
            return ([], 0)
        }
    }
}

// MARK: - Errors

enum AiLockError: LocalizedError {
    case notAuthenticated
    case invalidQR
    case clockInFailed(String)
    case clockOutFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You must be logged in."
        case .invalidQR: return "Invalid QR code."
        case .clockInFailed(let msg): return "Clock in failed: \(msg)"
        case .clockOutFailed(let msg): return "Clock out failed: \(msg)"
        }
    }
}
