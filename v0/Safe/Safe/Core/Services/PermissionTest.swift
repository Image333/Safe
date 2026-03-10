//
//  PermissionTest.swift
//  Safe
//
//  Created by System on 19/09/2025.
//

import Foundation

/// Test simple pour vérifier les permissions
class PermissionTest {
    
    static func testPermissionFlow() {
        
        let permissionService = PermissionService()
        
        // Test 1: Vérification des permissions actuelles
        let _ = permissionService.checkMicrophonePermission()
        let _ = permissionService.checkSpeechRecognitionPermission()
        
        
        // Test 2: Vérification des permissions essentielles
        let _ = permissionService.areEssentialPermissionsGranted()
        
        // Test 3: Permissions manquantes
        let missing = permissionService.getMissingPermissions()
        if missing.isEmpty {
        } else {
        }
        
    }
    
    static func testCoordinator() {
        
        let _ = VoiceMonitoringCoordinator()
        
        
    }
}
