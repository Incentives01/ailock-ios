import Foundation

struct GeocodingService {
    /// Reverse geocode coordinates to a readable address via Nominatim (OSM).
    /// Free, no API key required. Respects Nominatim usage policy with User-Agent.
    static func reverseGeocode(lat: Double, lng: Double) async -> String? {
        let urlString = "https://nominatim.openstreetmap.org/reverse?lat=\(lat)&lon=\(lng)&format=json"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("AiLockEmployee/1.0 (contact: support@ailock.me)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(NominatimResponse.self, from: data)
            if let addr = response.address {
                let short = addr.shortAddress
                if !short.isEmpty { return short }
            }
            return response.displayName
        } catch {
            print("Geocoding failed: \(error)")
            return nil
        }
    }
}
