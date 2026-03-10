import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                // Interface principale de l'app
                MainAppView()
                    .transition(.opacity.combined(with: .scale))
            } else {
                // Interface d'authentification
                AuthenticationView()
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.5), value: authManager.isAuthenticated)
    }
}

/// Vue principale de l'application (quand l'utilisateur est connecté)
struct MainAppView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Accueil")
                }
            
            ContactView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Proches")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Réglages")
                }
        }
        .accentColor(.blue)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
}
