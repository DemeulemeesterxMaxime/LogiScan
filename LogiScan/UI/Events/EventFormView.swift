//
//  EventFormView.swift
//  LogiScan
//
//  Created by Demeulemeester on 08/10/2025.
//

import SwiftData
import SwiftUI

struct EventFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // États du formulaire
    @State private var eventName = ""
    @State private var showValidationError = false
    @State private var validationMessage = ""
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        Text("Créer un événement")
                            .font(.title2)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Nom de l'événement", systemImage: "calendar")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            TextField("Ex: Concert Jazz Festival", text: $eventName)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                        }

                        Text("Vous pourrez compléter les détails de l'événement après sa création.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                }

                // Boutons
                HStack(spacing: 16) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    Button("Créer") {
                        createEvent()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, y: -2)
            }
            .navigationTitle("Nouvel événement")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Enregistrement...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(radius: 10)
                        )
                    }
                }
            }
            .alert("Validation", isPresented: $showValidationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
        }
    }

    private func createEvent() {
        guard !eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessage = "Veuillez saisir un nom pour l'événement"
            showValidationError = true
            return
        }

        isSaving = true

        Task {
            do {
                let event = Event(
                    eventId: "EVT-\(UUID().uuidString.prefix(8))",
                    name: eventName
                )

                modelContext.insert(event)

                // Sauvegarder dans SwiftData
                try modelContext.save()

                // Synchroniser immédiatement avec Firebase
                let firebaseService = FirebaseService()
                await firebaseService.saveEvent(event)

                print("✅ Événement créé et synchronisé: \(event.name)")

                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    validationMessage =
                        "Erreur lors de la création de l'événement: \(error.localizedDescription)"
                    showValidationError = true
                }
                print("❌ Erreur création événement: \(error)")
            }
        }
    }
}

#Preview {
    EventFormView()
        .modelContainer(for: [Event.self, Truck.self], inMemory: true)
}
