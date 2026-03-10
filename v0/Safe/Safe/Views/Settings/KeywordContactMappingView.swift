//
//  KeywordContactMappingView.swift
//  Safe
//
//  Configuration des liaisons mot-clé → contact
//

import SwiftUI

struct KeywordContactMappingView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var mappingService = LocalKeywordMappingService()
    @State private var contacts: [Contact] = []
    @State private var showingAddMapping = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        List {
            Section {
                Text("Associez des mots-clés à des contacts spécifiques pour un envoi automatique en cas d'urgence.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Configuration")
            }
            
            Section {
                if mappingService.mappings.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "link.circle")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("Aucune liaison configurée")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Exemple : 'orange' → Frère")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    ForEach(mappingService.mappings) { mapping in
                        if mapping.sendMode == .recordOnly {
                            // Mode "Enregistrement seul" - Pas besoin de contact
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("« \(mapping.keyword) »")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                    HStack {
                                        Image(systemName: mapping.sendMode.icon)
                                            .foregroundColor(.orange)
                                        Text(mapping.sendMode.rawValue)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    // Badge pour indiquer si local ou serveur
                                    if mapping.serverId != nil {
                                        Text("☁️ Synchronisé")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    } else {
                                        Text("📱 Local")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                                }
                                
                                Spacer()
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task {
                                        try? await mappingService.removeMapping(mapping)
                                    }
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                        } else if let contact = contacts.first(where: { $0.id == mapping.contactId }) {
                            // Mode "Envoi automatique" - Afficher le contact
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("« \(mapping.keyword) »")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                    HStack {
                                        Image(systemName: mapping.sendMode.icon)
                                            .foregroundColor(.green)
                                        Text("→ \(contact.name) (\(contact.email ?? "pas d'email"))")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Text("📧 Envoi automatique par email")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    
                                    // Badge pour indiquer si local ou serveur
                                    if mapping.serverId != nil {
                                        Text("☁️ Synchronisé")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    } else {
                                        Text("📱 Local")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                                }
                                
                                Spacer()
                                
                                Text("Priorité \(mapping.priority)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(8)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task {
                                        try? await mappingService.removeMapping(mapping)
                                    }
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Liaisons actives (\(mappingService.mappings.count))")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("•")
                        Text("'orange' → Email automatique au frère")
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("•")
                        Text("'fleur' → Email automatique à Margot")
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("•")
                        Text("'enregistrer' → Enregistrement seul, sans envoi")
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("⚠️")
                        Text("Le contact doit avoir un email configuré")
                    }
                    .font(.caption2)
                    .foregroundColor(.orange)
                }
                .foregroundColor(.secondary)
            } header: {
                Text("Exemples")
            } footer: {
                Text("Les emails sont envoyés automatiquement via SMTP après l'enregistrement de 10 secondes.")
                    .font(.caption2)
            }
        }
        .navigationTitle("Liaisons Mot-clé/Contact")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                showingAddMapping = true
            } label: {
                Image(systemName: "plus")
            }
            .disabled(contacts.isEmpty)
        }
        .sheet(isPresented: $showingAddMapping) {
            AddMappingView(contacts: contacts) { keyword, contactId, priority, sendMode in
                Task {
                    try? await mappingService.addMapping(
                        keyword: keyword,
                        contactId: contactId,
                        priority: priority,
                        sendMode: sendMode
                    )
                }
            }
        }
        .task {
            try? await mappingService.loadMappings()
            await loadContacts()
        }
        .refreshable {
            try? await mappingService.loadMappings()
            await loadContacts()
        }
        .alert("Erreur", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Une erreur est survenue")
        }
    }
    
    private func loadContacts() async {
        isLoading = true
        defer { isLoading = false }
        
        guard let token = authManager.token else {
            errorMessage = "Vous devez être connecté"
            showingError = true
            return
        }
        
        do {
            contacts = try await APIService.shared.getContacts(token: token)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

struct AddMappingView: View {
    @Environment(\.dismiss) private var dismiss
    
    let contacts: [Contact]
    let onSave: (String, Int?, Int, SendMode) -> Void
    
    @State private var keyword = ""
    @State private var selectedContactId: Int?
    @State private var priority = 1
    @State private var sendMode: SendMode = .sendToContacts
    
    var body: some View {
        NavigationView {
            Form {
                Section("Mot-clé") {
                    TextField("Ex: orange, fleur, aide...", text: $keyword)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Text("Mot ou phrase à détecter pour déclencher l'alerte")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Mode d'action") {
                    Picker("Action", selection: $sendMode) {
                        ForEach(SendMode.allCases, id: \.self) { mode in
                            HStack {
                                Image(systemName: mode.icon)
                                Text(mode.rawValue)
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text(sendMode.description)
                        .font(.caption)
                        .foregroundColor(sendMode == .sendToContacts ? .green : .orange)
                }
                
                if sendMode == .sendToContacts {
                    Section("Contact associé") {
                        Picker("Contact", selection: $selectedContactId) {
                            Text("Choisir un contact").tag(nil as Int?)
                            ForEach(contacts) { contact in
                                if let email = contact.email, !email.isEmpty {
                                    Text("\(contact.name) (\(email))").tag(contact.id as Int?)
                                } else {
                                    Text("\(contact.name) (⚠️ pas d'email)").tag(contact.id as Int?)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        
                        Text("📧 Contact qui recevra l'email avec l'enregistrement audio")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let selectedId = selectedContactId,
                           let selectedContact = contacts.first(where: { $0.id == selectedId }),
                           selectedContact.email == nil || selectedContact.email!.isEmpty {
                            Text("⚠️ Ce contact n'a pas d'email configuré")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Section("Priorité") {
                        Stepper("Priorité: \(priority)", value: $priority, in: 1...10)
                        Text("1 = Priorité la plus élevée. Utilisé si plusieurs contacts pour un même mot-clé.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Nouvelle liaison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sauvegarder") {
                        // Valider selon le mode
                        if sendMode == .recordOnly {
                            // Pour recordOnly, pas besoin de contact
                            onSave(keyword.trimmingCharacters(in: .whitespaces), nil, priority, sendMode)
                            dismiss()
                        } else if let contactId = selectedContactId {
                            // Pour sendToContacts, besoin d'un contact
                            onSave(keyword.trimmingCharacters(in: .whitespaces), contactId, priority, sendMode)
                            dismiss()
                        }
                    }
                    .disabled(keyword.trimmingCharacters(in: .whitespaces).isEmpty || 
                             (sendMode == .sendToContacts && selectedContactId == nil))
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        KeywordContactMappingView()
            .environmentObject(AuthManager())
    }
}
