//
//  AppIDView.swift
//  GetMoreRam
//

import SwiftUI

struct AppIDEditView : View {
    @StateObject var viewModel : AppIDModel
    @State private var errorShow = false
    @State private var errorInfo = ""
    @State private var isAdding = false

    var body: some View {
        Form {
            Section {
                Button {
                    Task { await addCapability("INCREASED_MEMORY_LIMIT") }
                } label: {
                    Text("Add Increased Memory Limit")
                }
                .disabled(isAdding)
            }

            Section {
                Text(viewModel.result)
                    .font(.system(.subheadline, design: .monospaced))
            } header: {
                Text("Server Response")
            }
        }
        .alert("Error", isPresented: $errorShow) {
            Button("OK".loc, action: {})
        } message: {
            Text(errorInfo)
        }
        .navigationTitle(viewModel.bundleID)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isAdding { ProgressView() }
        }
    }

    func addCapability(_ capability: String) async {
        isAdding = true
        defer { isAdding = false }
        do {
            try await viewModel.addCapability(capability)
        } catch {
            errorInfo = error.detailedDescription
            errorShow = true
        }
    }
}

struct AppIDView : View {
    @StateObject var viewModel : AppIDViewModel
    @State private var errorShow = false
    @State private var errorInfo = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    ForEach(viewModel.appIDs, id: \.self) { appID in
                        NavigationLink {
                            AppIDEditView(viewModel: appID)
                        } label: {
                            Text(appID.bundleID)
                        }
                    }
                } header: {
                    Text("App IDs")
                }

                Section {
                    Button("Refresh") {
                        Task { await refreshButtonClicked() }
                    }
                }
            }
            .alert("Error", isPresented: $errorShow) {
                Button("OK".loc, action: {})
            } message: {
                Text(errorInfo)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    func refreshButtonClicked() async {
        do {
            try await viewModel.fetchAppIDs()
        } catch {
            errorInfo = error.detailedDescription
            errorShow = true
        }
    }
}

struct ExperimentsView: View {
    @StateObject private var viewModel = AppIDViewModel()
    @State private var selectedAppID: AppIDModel?
    @State private var capability = ""
    @State private var errorShow = false
    @State private var errorInfo = ""
    @State private var isAdding = false

    var body: some View {
        Form {
            Section {
                Picker("App ID", selection: $selectedAppID) {
                    Text("Choose an App ID").tag(nil as AppIDModel?)
                    ForEach(viewModel.appIDs, id: \.self) { appID in
                        Text(appID.bundleID).tag(Optional(appID))
                    }
                }
            } header: {
                Text("Target")
            }

            Section {
                TextField("Capability identifier", text: $capability)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                Button("Add Anything") {
                    Task { await addAnything() }
                }
                .disabled(
                    isAdding ||
                    selectedAppID == nil ||
                    capability.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            } header: {
                Text("Add Anything")
            } footer: {
                Text("Enter the exact capability identifier accepted by Apple's Developer API.")
            }

            if let selectedAppID {
                Section {
                    Text(selectedAppID.result)
                        .font(.system(.footnote, design: .monospaced))
                } header: {
                    Text("Server Response")
                }
            }
        }
        .navigationTitle("Experiments")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadAppIDs() }
        .alert("Error", isPresented: $errorShow) {
            Button("OK".loc, action: {})
        } message: {
            Text(errorInfo)
        }
        .overlay {
            if isAdding { ProgressView() }
        }
    }

    private func loadAppIDs() async {
        do {
            try await viewModel.fetchAppIDs()
            await MainActor.run {
                if selectedAppID == nil {
                    selectedAppID = viewModel.appIDs.first
                }
            }
        } catch {
            errorInfo = error.detailedDescription
            errorShow = true
        }
    }

    private func addAnything() async {
        guard let selectedAppID else { return }
        isAdding = true
        defer { isAdding = false }

        do {
            try await selectedAppID.addCapability(capability)
        } catch {
            errorInfo = error.detailedDescription
            errorShow = true
        }
    }
}
