import Foundation

// MARK: - Security Mode

enum SecurityMode: String, Codable {
    case secure
    case focus
    case none

    var displayName: String {
        switch self {
        case .secure: return "Secure Mode"
        case .focus: return "Focus Mode"
        case .none: return "No Lock"
        }
    }

    var badgeColor: String {
        switch self {
        case .secure: return "red"
        case .focus: return "blue"
        case .none: return "gray"
        }
    }

    var description: String {
        switch self {
        case .secure: return "All apps blocked during your work session"
        case .focus: return "Distracting apps + AI tools blocked. Phone & Messages available"
        case .none: return "Attendance only — no app restrictions"
        }
    }
}

// MARK: - QR Payload

struct QRPayload: Codable {
    let locationId: String
    let businessId: String
    let mode: String

    enum CodingKeys: String, CodingKey {
        case locationId = "location_id"
        case businessId = "business_id"
        case mode
    }

    var securityMode: SecurityMode {
        SecurityMode(rawValue: mode) ?? .none
    }
}

// MARK: - Employee

struct Employee: Codable, Identifiable {
    let id: String
    let businessId: String?
    let departmentId: String?
    let name: String?
    let email: String?
    let employeeCode: String?
    let focusOptIn: Bool?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, email
        case businessId = "business_id"
        case departmentId = "department_id"
        case employeeCode = "employee_code"
        case focusOptIn = "focus_opt_in"
        case createdAt = "created_at"
    }
}

// MARK: - Location

struct Location: Codable, Identifiable {
    let id: String
    let businessId: String?
    let name: String
    let address: String?
    let isRemote: Bool?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, address
        case businessId = "business_id"
        case isRemote = "is_remote"
        case createdAt = "created_at"
    }
}

// MARK: - Attendance Session

struct AttendanceSession: Codable, Identifiable {
    let id: String?
    let employeeId: String?
    let locationId: String?
    let shiftId: String?
    let clockInAt: String?
    let clockOutAt: String?
    let clockInLat: Double?
    let clockInLng: Double?
    let clockOutLat: Double?
    let clockOutLng: Double?
    let clockInAddress: String?
    let clockOutAddress: String?
    let method: String?
    let status: String?
    let isRemote: Bool?
    let securityMode: String?
    let totalMinutes: Int?
    let createdAt: String?

    // Joined location name for history display
    let location: LocationRef?

    enum CodingKeys: String, CodingKey {
        case id, method, status, location
        case employeeId = "employee_id"
        case locationId = "location_id"
        case shiftId = "shift_id"
        case clockInAt = "clock_in_at"
        case clockOutAt = "clock_out_at"
        case clockInLat = "clock_in_lat"
        case clockInLng = "clock_in_lng"
        case clockOutLat = "clock_out_lat"
        case clockOutLng = "clock_out_lng"
        case clockInAddress = "clock_in_address"
        case clockOutAddress = "clock_out_address"
        case isRemote = "is_remote"
        case securityMode = "security_mode"
        case totalMinutes = "total_minutes"
        case createdAt = "created_at"
    }

    var isActive: Bool {
        status == "active"
    }

    var clockInDate: Date? {
        guard let str = clockInAt else { return nil }
        return ISO8601DateFormatter().date(from: str)
            ?? DateFormatter.supabase.date(from: str)
    }

    var clockOutDate: Date? {
        guard let str = clockOutAt else { return nil }
        return ISO8601DateFormatter().date(from: str)
            ?? DateFormatter.supabase.date(from: str)
    }

    var mode: SecurityMode {
        SecurityMode(rawValue: securityMode ?? "none") ?? .none
    }

    var durationText: String {
        if let mins = totalMinutes {
            let h = mins / 60
            let m = mins % 60
            return h > 0 ? "\(h)h \(m)m" : "\(m)m"
        }
        guard let start = clockInDate else { return "--" }
        let end = clockOutDate ?? Date()
        let mins = Int(end.timeIntervalSince(start) / 60)
        let h = mins / 60
        let m = mins % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    var locationName: String {
        location?.name ?? (isRemote == true ? "Remote" : "Unknown")
    }
}

// MARK: - Location Reference (for joined queries)

struct LocationRef: Codable {
    let name: String
}

// MARK: - Clock In Request

struct ClockInRequest: Codable {
    let pEmployeeId: String
    let pLocationId: String
    let pLat: Double?
    let pLng: Double?
    let pIsRemote: Bool
    let pMethod: String
    let pClockInAddress: String?
    let pSecurityMode: String?

    enum CodingKeys: String, CodingKey {
        case pEmployeeId = "p_employee_id"
        case pLocationId = "p_location_id"
        case pLat = "p_lat"
        case pLng = "p_lng"
        case pIsRemote = "p_is_remote"
        case pMethod = "p_method"
        case pClockInAddress = "p_clock_in_address"
        case pSecurityMode = "p_security_mode"
    }
}

// MARK: - Clock Out Request

struct ClockOutRequest: Codable {
    let pSessionId: String
    let pLat: Double?
    let pLng: Double?
    let pClockOutAddress: String?

    enum CodingKeys: String, CodingKey {
        case pSessionId = "p_session_id"
        case pLat = "p_lat"
        case pLng = "p_lng"
        case pClockOutAddress = "p_clock_out_address"
    }
}

// MARK: - Nominatim Response

struct NominatimResponse: Codable {
    let displayName: String?
    let address: NominatimAddress?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case address
    }
}

struct NominatimAddress: Codable {
    let road: String?
    let houseNumber: String?
    let suburb: String?
    let city: String?
    let town: String?
    let state: String?
    let country: String?
    let postcode: String?

    enum CodingKeys: String, CodingKey {
        case road, suburb, city, town, state, country, postcode
        case houseNumber = "house_number"
    }

    var shortAddress: String {
        var parts: [String] = []
        if let num = houseNumber, let road = road {
            parts.append("\(num) \(road)")
        } else if let road = road {
            parts.append(road)
        }
        if let suburb = suburb { parts.append(suburb) }
        if let city = city ?? town { parts.append(city!) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Date Formatter

extension DateFormatter {
    static let supabase: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static let display: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static let timeOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()
}
