//
//  CompilationTest.swift
//  Safe
//
//  Created by System on 19/09/2025.
//

import Foundation

/// Test de compilation pour vérifier que toutes les erreurs sont corrigées
class CompilationTest {
    
    static func runTests() {
        testPermissionsManager()
        testContinuousListeningManager()
        testVoiceMonitoringCoordinator()
    }
    
    private static func testPermissionsManager() {
        let manager = PermissionsManager()
        manager.checkAllPermissions()
        _ = manager.areEssentialPermissionsGranted()
    }
    
    private static func testContinuousListeningManager() {
        let manager = ContinuousListeningManager()
        _ = manager.checkPermissions()
    }
    
    private static func testVoiceMonitoringCoordinator() {
        _ = VoiceMonitoringCoordinator()
    }
}

// Extensions pour les tests
extension ContinuousListeningManager {
    /// Méthode publique pour tester la vérification des permissions
    func testCheckPermissions() -> (mic: Bool, speech: Bool) {
        return checkPermissions()
    }
}
