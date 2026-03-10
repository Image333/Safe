//
//  SafetyTests.swift
//  Safe
//
//  Created by Imane on 14/08/2025.
//

import Foundation

/// Tests de sécurité pour éviter les crashes de conversion
final class SafetyTests {
    
    static func testDoubleToIntConversions() {
        
        let testValues: [Double] = [
            0.0,
            -1.0,
            100.5,
            30.0,
            Double.infinity,
            -Double.infinity,
            Double.nan,
            Double(Int.max) + 1000,
            Double(Int.min) - 1000
        ]
        
        for value in testValues {
            let _ = safeDoubleToInt(value)
        }
    }
    
    static func testTimeIntervalFormatting() {
        
        let testIntervals: [TimeInterval] = [
            0.0,
            30.0,
            3600.0, // 1 heure
            3665.0, // 1h 1min 5s
            Double.infinity,
            -100.0,
            Double.nan
        ]
        
        for interval in testIntervals {
            let _ = formatDurationSafely(interval)
        }
    }
    
    // Helper methods for testing
    private static func safeDoubleToInt(_ value: Double) -> Int {
        if value.isInfinite {
            return value > 0 ? Int.max : Int.min
        }
        if value.isNaN {
            return 0
        }
        if value > Double(Int.max) {
            return Int.max
        }
        if value < Double(Int.min) {
            return Int.min
        }
        return Int(value)
    }
    
    private static func formatDurationSafely(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else {
            return seconds.isInfinite ? "∞" : "invalide"
        }
        
        let safeSeconds = min(seconds, Double(Int.max))
        let hours = Int(safeSeconds) / 3600
        let minutes = (Int(safeSeconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)min"
        } else if minutes > 0 {
            return "\(minutes)min"
        } else {
            return "< 1min"
        }
    }
}

// Extension pour faciliter l'appel des tests
extension SafetyTests {
    static func runAllTests() {
        testDoubleToIntConversions()
        testTimeIntervalFormatting()
    }
}
