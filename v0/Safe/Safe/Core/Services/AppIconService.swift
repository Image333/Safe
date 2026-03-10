//
//  AppIconService.swift
//  Safe

import UIKit

class AppIconService: ObservableObject {
    @Published var currentIcon: String = "Default"
    
    enum AppIcon: String, CaseIterable {
        case `default` = "AppIcon"
        case calculator = "AppIcon-Calculator"
        case notes = "AppIcon-Notes"
        
        var displayName: String {
            switch self {
            case .default:
                return "Défaut"
            case .calculator:
                return "Calculatrice"
            case .notes:
                return "Notes"
            }
        }
        
        var previewImageName: String {
            return self.rawValue
        }
        
        var appName: String {
            switch self {
            case .default:
                return "Safe"
            case .calculator:
                return "Calculatrice"
            case .notes:
                return "Notes"
            }
        }
    }
    
    init() {
        currentIcon = getCurrentAppIcon()
    }
    
    var currentAppIcon: AppIcon {
        if let iconName = UIApplication.shared.alternateIconName {
            return AppIcon(rawValue: iconName) ?? .default
        }
        return .default
    }
    
    var currentAppName: String {
        return currentAppIcon.appName
    }
    
    func getCurrentAppIcon() -> String {
        if let iconName = UIApplication.shared.alternateIconName {
            if let appIcon = AppIcon(rawValue: iconName) {
                return appIcon.displayName
            }
            return iconName
        }
        return "Défaut"
    }
    
    func setAppIcon(_ iconName: AppIcon) {
        
        
        guard UIApplication.shared.supportsAlternateIcons else {
            return
        }
        
        let alternateIconName = iconName == .default ? nil : iconName.rawValue
        
        
        UIApplication.shared.setAlternateIconName(alternateIconName) { error in
            DispatchQueue.main.async {
                if error != nil {
                } else {
                    self.currentIcon = iconName.displayName

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    }
                    NotificationCenter.default.post(name: .appIconDidChange, object: iconName)
                }
            }
        }
    }
    
    func isSupported() -> Bool {
        return UIApplication.shared.supportsAlternateIcons
    }
}

extension Notification.Name {
    static let appIconDidChange = Notification.Name("AppIconDidChange")
}
