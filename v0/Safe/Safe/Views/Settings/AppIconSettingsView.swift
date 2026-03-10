//
//  AppIconSettingsView.swift
//  Safe

import SwiftUI

struct AppIconSettingsView: View {
    @StateObject private var appIconService = AppIconService()
    @State private var showingAlert = false
    @State private var isChangingIcon = false
    
    var body: some View {
        NavigationView {
            VStack {
                if !appIconService.isSupported() {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("Icônes alternatives non supportées")
                            .font(.headline)
                        
                        Text("Votre appareil ne supporte pas les icônes d'application alternatives.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    Form {
                        Section {
                            ForEach(AppIconService.AppIcon.allCases, id: \.self) { icon in
                                AppIconRow(
                                    icon: icon,
                                    isSelected: isCurrentIcon(icon),
                                    isChanging: isChangingIcon,
                                    onTap: {
                                        changeIcon(to: icon)
                                    }
                                )
                            }
                        } header: {
                            Text("Choisissez une icône d'application")
                        } footer: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("L'icône sélectionnée apparaîtra sur votre écran d'accueil.")
                                
                                if isChangingIcon {
                                    HStack {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Changement en cours...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Icône de l'app")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Changement d'icône", isPresented: $showingAlert) {
            Button("OK") { }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appIconDidChange)) { _ in
            isChangingIcon = false
        }
    }
    
    private func isCurrentIcon(_ icon: AppIconService.AppIcon) -> Bool {
        let currentIconName = UIApplication.shared.alternateIconName ?? "AppIcon"
        return currentIconName == icon.rawValue || (icon == .default && currentIconName == "AppIcon")
    }
    
    private func changeIcon(to icon: AppIconService.AppIcon) {
        isChangingIcon = true
        appIconService.setAppIcon(icon)
        
        // Délai plus long pour laisser le temps à iOS de traiter le changement
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showingAlert = false
            isChangingIcon = false
        }
    }
}

struct AppIconRow: View {
    let icon: AppIconService.AppIcon
    let isSelected: Bool
    let isChanging: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icône de prévisualisation avec vraie image PNG
            Group {
                Image(getPreviewImageName())
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )
                    .overlay(
                        Group {
                            if isChanging && isSelected {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.4))
                                    .overlay(
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    )
                            }
                        }
                    )
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(icon.displayName)
                    .font(.headline)
                    .foregroundColor(isSelected ? .blue : .primary)
                
                Text(iconDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                if isChanging {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isChanging {
                onTap()
            }
        }
        .disabled(isChanging)
        .opacity(isChanging && !isSelected ? 0.6 : 1.0)
    }
    
    // Fonction pour obtenir le nom de l'image de prévisualisation
    private func getPreviewImageName() -> String {
        switch icon {
        case .default:
            return "AppIcon-Preview"
        case .calculator:
            return "AppIcon-Calculator-Preview"
        case .notes:
            return "AppIcon-Notes-Preview"
        }
    }
    
    private var iconDescription: String {
        switch icon {
        case .default:
            return "Icône par défaut de Safe"
        case .calculator:
            return "Style inspiré de la calculatrice"
        case .notes:
            return "Style inspiré des notes"
        }
    }
}

#Preview {
    AppIconSettingsView()
}
