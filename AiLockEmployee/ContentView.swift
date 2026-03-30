import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var supabase: SupabaseService
    @State private var isCheckingSession = true

    var body: some View {
        Group {
            if isCheckingSession {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "3B82F6"))
                        Text("AiLock")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        ProgressView()
                            .tint(.white)
                    }
                }
            } else if authViewModel.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .task {
            await authViewModel.checkExistingSession()
            isCheckingSession = false
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @StateObject private var homeViewModel = HomeViewModel()

    var body: some View {
        TabView {
            HomeView()
                .environmentObject(homeViewModel)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }

            QRScannerView()
                .environmentObject(homeViewModel)
                .tabItem {
                    Image(systemName: "qrcode.viewfinder")
                    Text("Scan QR")
                }

            HistoryView()
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("History")
                }

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
        }
        .tint(Color(hex: "3B82F6"))
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 59, 130, 246)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
