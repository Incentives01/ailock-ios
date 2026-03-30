import SwiftUI

@main
struct AiLockEmployeeApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var supabase = SupabaseService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(supabase)
                .preferredColorScheme(.dark)
        }
    }
}
