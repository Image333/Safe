//
//  SafeApp.swift
//  Safe
//
//  Created by Imane on 04/07/2025.
//

import SwiftUI

@main
struct SafeApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var locationService = LocationService.shared
    
    init() {
        LocationService.shared.requestPermission()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .withDependencies(DependencyContainer.shared)
        }
    }
}
