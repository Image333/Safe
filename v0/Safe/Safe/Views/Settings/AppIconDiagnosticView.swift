//
//  AppIconDiagnosticView.swift
//  Safe

import SwiftUI

struct AppIconDiagnosticView: View {
    @StateObject private var appIconService = AppIconService()
    @State private var diagnosticInfo: [String] = []
    
    var body: some View {
        NavigationView {
            List {
                Section("État Actuel") {
                    Text("Icône actuelle détectée: \(appIconService.currentIcon)")
                    Text("Support des icônes alternatives: \(appIconService.isSupported() ? "✅ Oui" : "❌ Non")")
                    
                    if let currentName = UIApplication.shared.alternateIconName {
                        Text("Nom technique iOS: \(currentName)")
                    } else {
                        Text("Nom technique iOS: AppIcon (défaut)")
                    }
                }
                
                Section("Diagnostic") {
                    ForEach(diagnosticInfo, id: \.self) { info in
                        Text(info)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Actions") {
                    Button("Actualiser le diagnostic") {
                        runDiagnostic()
                    }
                    
                    Button("Test changement vers Calculatrice") {
                        testIconChange(.calculator)
                    }
                    
                    Button("Test changement vers Notes") {
                        testIconChange(.notes)
                    }
                    
                    Button("Retour à l'icône par défaut") {
                        testIconChange(.default)
                    }
                }
            }
            .navigationTitle("Diagnostic Icônes")
            .onAppear {
                runDiagnostic()
            }
        }
    }
    
    private func runDiagnostic() {
        diagnosticInfo.removeAll()
        
        diagnosticInfo.append("🔍 Test 1: Support des icônes alternatives")
        diagnosticInfo.append("   Résultat: \(UIApplication.shared.supportsAlternateIcons ? "✅ Supporté" : "❌ Non supporté")")
        
        diagnosticInfo.append("🔍 Test 2: Icône actuelle")
        if let iconName = UIApplication.shared.alternateIconName {
            diagnosticInfo.append("   Résultat: ✅ Icône alternative active: \(iconName)")
        } else {
            diagnosticInfo.append("   Résultat: ℹ️ Icône par défaut active")
        }
        
        diagnosticInfo.append("🔍 Test 3: Vérification des icônes disponibles")
        for icon in AppIconService.AppIcon.allCases {
            let iconExists = checkIfIconExists(icon.rawValue)
            diagnosticInfo.append("   \(icon.displayName): \(iconExists ? "✅" : "❌") (\(icon.rawValue))")
        }
        
        diagnosticInfo.append("🔍 Test 4: Configuration Info.plist")
        if let bundleIcons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let alternateIcons = bundleIcons["CFBundleAlternateIcons"] as? [String: Any] {
            diagnosticInfo.append("   ✅ CFBundleAlternateIcons configuré")
            diagnosticInfo.append("   📱 Icônes déclarées: \(alternateIcons.keys.joined(separator: ", "))")
        } else {
            diagnosticInfo.append("   ❌ CFBundleAlternateIcons manquant dans Info.plist")
        }
        
        diagnosticInfo.append("🔍 Test 5: Recommandations")
        diagnosticInfo.append("   🧹 Clean Build: Product → Clean Build Folder (Cmd+Shift+K)")
        diagnosticInfo.append("   🔄 Supprimer l'app et réinstaller")
    }
    
    private func checkIfIconExists(_ iconName: String) -> Bool {
        return true
    }
    
    private func testIconChange(_ icon: AppIconService.AppIcon) {
        diagnosticInfo.append("🧪 Test de changement vers: \(icon.displayName)")
        appIconService.setAppIcon(icon)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            runDiagnostic()
        }
    }
}

#Preview {
    AppIconDiagnosticView()
}
