//
//  KeywordSettingsView.swift
//  Safe
//
//  Created by Imane on 14/08/2025.
//

import SwiftUI

struct KeywordSettingsView: View {
    // Utiliser le service injecté au lieu de créer une nouvelle instance
    @Injected(\.keywordDetectionService) private var keywordService
    @State private var keywords: [String] = []
    @State private var newKeyword: String = ""
    @State private var showingAddAlert = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                // Section d'ajout de nouveau mot-clé
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ajouter un mot-clé")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        TextField("Ex: aide, urgence...", text: $newKeyword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($isTextFieldFocused)
                            .autocapitalization(.none)
                            .submitLabel(.done)
                            .onSubmit {
                                addKeyword()
                            }
                        
                        Button {
                            addKeyword()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(newKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .accentColor)
                        }
                        .disabled(newKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding()
                
                // Liste des mots-clés
                List {
                    if keywords.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "text.word.spacing")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)
                            Text("Aucun mot-clé configuré")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Ajoutez des mots-clés pour activer la détection d'urgence")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(keywords, id: \.self) { keyword in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                
                                Text(keyword)
                                    .font(.body)
                                
                                Spacer()
                                
                                Button {
                                    removeKeyword(keyword)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Mots-clés d'urgence")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Effacer tout") {
                        clearAllKeywords()
                    }
                    .foregroundColor(.red)
                    .disabled(keywords.isEmpty)
                }
            }
            .onAppear {
                loadKeywords()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadKeywords() {
        keywords = keywordService.getKeywordList()
    }
    
    private func addKeyword() {
        let cleanedKeyword = newKeyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanedKeyword.isEmpty else { return }
        
        // Vérifier si le mot-clé existe déjà
        guard !keywords.contains(cleanedKeyword) else {
            newKeyword = ""
            return
        }
        
        keywordService.addKeyword(cleanedKeyword)
        loadKeywords()
        newKeyword = ""
        isTextFieldFocused = false
    }
    
    private func removeKeyword(_ keyword: String) {
        keywordService.removeKeyword(keyword)
        loadKeywords()
    }
    
    private func clearAllKeywords() {
        keywords.forEach { keyword in
            keywordService.removeKeyword(keyword)
        }
        keywordService.clearDetectionHistory()
        loadKeywords()
    }
}

#Preview {
    KeywordSettingsView()
}
