//
//  ContactView.swift
//  Safe

import SwiftUI

struct ContactView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var contacts: [Contact] = []
    @State private var showingAddContact = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var recordings: [URL] = []
    @StateObject private var fileManagementService = FileManagementService()
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading && contacts.isEmpty {
                    ProgressView("Chargement des contacts...")
                } else if contacts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Aucun contact")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Ajoutez vos proches pour les contacter rapidement en cas d'urgence")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    List {
                        Section("Mes proches") {
                            ForEach(contacts) { contact in
                                ContactRow(contact: contact)
                            }
                            .onDelete(perform: deleteContact)
                        }
                        
                        if !recordings.isEmpty {
                            Section("Enregistrements d'urgence") {
                                ForEach(recordings, id: \.self) { url in
                                    RecordingRowView(url: url) {
                                        loadRecordings()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Proches")
            .toolbar {
                Button(action: {
                    showingAddContact = true
                }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddContact) {
                AddContactView { name, phone, email, contactType, priority in
                    Task {
                        await createContact(name: name, phone: phone, email: email, contactType: contactType, priority: priority)
                    }
                }
            }
            .task {
                await loadContacts()
                loadRecordings()
            }
            .refreshable {
                await loadContacts()
                loadRecordings()
            }
            .onReceive(NotificationCenter.default.publisher(for: .emergencyRecordingComplete)) { _ in
                loadRecordings()
            }
            .alert("Erreur", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Une erreur est survenue")
            }
        }
    }
    
    func loadContacts() async {
        isLoading = true
        defer { isLoading = false }
        
        guard let token = authManager.token else {
            errorMessage = "Vous devez être connecté pour accéder aux contacts"
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
    
    func createContact(name: String, phone: String, email: String?, contactType: String?, priority: Int) async {
        guard let token = authManager.token else {
            errorMessage = "Vous devez être connecté pour créer un contact"
            showingError = true
            return
        }
        
        let input = ContactInput(
            email: email,
            contactName: name,
            phoneNumber: phone,
            contactType: contactType,
            priorityOrder: priority
        )
        
        do {
            let newContact = try await APIService.shared.createContact(token: token, input: input)
            contacts.append(newContact)
            contacts.sort { $0.priorityOrder < $1.priorityOrder }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    func deleteContact(at offsets: IndexSet) {
        guard let token = authManager.token else {
            errorMessage = "Vous devez être connecté pour supprimer un contact"
            showingError = true
            return
        }
        
        for index in offsets {
            let contact = contacts[index]
            Task {
                do {
                    try await APIService.shared.deleteContact(token: token, contactId: contact.id)
                    _ = await MainActor.run {
                        contacts.remove(at: index)
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
        }
    }
    
    func loadRecordings() {
        recordings = fileManagementService.getAllRecordings()
    }
}

struct ContactRow: View {
    let contact: Contact
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text(contact.name)
                    .font(.headline)
                Text(contact.phone)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                if let url = URL(string: "tel:\(contact.phone)") {
                    UIApplication.shared.open(url)
                }
            }) {
                Image(systemName: "phone.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddContactView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var contactType = "friend"
    @State private var priority = 1
    
    let onSave: (String, String, String?, String?, Int) -> Void
    
    let contactTypes = ["family", "friend", "colleague", "other"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Informations du proche") {
                    TextField("Nom", text: $name)
                    TextField("Numéro de téléphone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email (optionnel)", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                
                Section("Type de contact") {
                    Picker("Type", selection: $contactType) {
                        Text("Famille").tag("family")
                        Text("Ami(e)").tag("friend")
                        Text("Collègue").tag("colleague")
                        Text("Autre").tag("other")
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Priorité") {
                    Stepper("Priorité: \(priority)", value: $priority, in: 1...10)
                    Text("1 = Priorité la plus élevée")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Nouveau proche")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sauvegarder") {
                        let emailToSave = email.isEmpty ? nil : email
                        onSave(name, phone, emailToSave, contactType, priority)
                        dismiss()
                    }
                    .disabled(name.isEmpty || phone.isEmpty)
                }
            }
        }
    }
}

#Preview {
    ContactView()
}
