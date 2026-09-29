//
//  AppIDView.swift
//  GetMoreRam
//

import SwiftUI

struct AppIDEditView: View {
    @StateObject var viewModel: AppIDModel

    @State private var errorShow = false
    @State private var errorInfo = ""
    @State private var isAdding = false

    var body: some View {
        Form {
            Section {
                Button {
                    Task {
                        await addCapability("INCREASED_MEMORY_LIMIT")
                    }
                } label: {
                    Label(
                        "Add Increased Memory Limit",
                        systemImage: "memorychip"
                    )
                }
                .disabled(isAdding)
            } header: {
                Text("Capabilities")
            } footer: {
                Text("Request the increased memory limit capability for this App ID.")
            }

            Section {
                if viewModel.result.isEmpty {
                    Text("No server response yet.")
                        .foregroundStyle(.secondary)
                } else {
                    Text(viewModel.result)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
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
            if isAdding {
                ProgressView("Updating capability…")
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    func addCapability(_ capability: String) async {
        isAdding = true
        defer {
            isAdding = false
        }

        do {
            try await viewModel.addCapability(capability)
        } catch {
            errorInfo = error.detailedDescription
            errorShow = true
        }
    }
}

struct AppIDView: View {
    @StateObject var viewModel: AppIDViewModel

    @State private var errorShow = false
    @State private var errorInfo = ""
    @State private var isRefreshing = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    if viewModel.appIDs.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "square.stack.3d.up")
                                .font(.system(size: 30))
                                .foregroundStyle(.secondary)

                            Text("No App IDs Loaded")
                                .font(.headline)

                            Text("Sign in and refresh to load your Apple Developer App IDs.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        ForEach(viewModel.appIDs, id: \.self) { appID in
                            NavigationLink {
                                AppIDEditView(viewModel: appID)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "app.badge")
                                        .font(.title3)
                                        .foregroundStyle(.tint)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(appID.bundleID)
                                            .font(.body)
                                            .foregroundStyle(.primary)

                                        Text("App ID")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 3)
                            }
                        }
                    }
                } header: {
                    Text("App IDs")
                }

                Section {
                    Button {
                        Task {
                            await refreshButtonClicked()
                        }
                    } label: {
                        HStack {
                            Spacer()

                            if isRefreshing {
                                ProgressView()
                                    .padding(.trailing, 6)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }

                            Text(isRefreshing ? "Refreshing…" : "Refresh")
                            Spacer()
                        }
                    }
                    .disabled(isRefreshing)
                }
            }
            .navigationTitle("App IDs")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $errorShow) {
                Button("OK".loc, action: {})
            } message: {
                Text(errorInfo)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    func refreshButtonClicked() async {
        isRefreshing = true
        defer {
            isRefreshing = false
        }

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
    @State private var isLoading = false

    var body: some View {
        Form {
            Section {
                if isLoading {
                    HStack {
                        ProgressView()
                        Text("Loading App IDs…")
                            .foregroundStyle(.secondary)
                    }
                } else if viewModel.appIDs.isEmpty {
                    Text("No App IDs available. Sign in and try again.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("App ID", selection: $selectedAppID) {
                        Text("Choose an App ID")
                            .tag(nil as AppIDModel?)

                        ForEach(viewModel.appIDs, id: \.self) { appID in
                            Text(appID.bundleID)
                                .tag(Optional(appID))
                        }
                    }
                }
            } header: {
                Text("Target")
            }

            Section {
                TextField(
                    "Capability identifier",
                    text: $capability
                )
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()

                Button {
                    Task {
                        await addAnything()
                    }
                } label: {
                    HStack {
                        Spacer()

                        if isAdding {
                            ProgressView()
                                .padding(.trailing, 6)
                        } else {
                            Image(systemName: "plus.circle.fill")
                        }

                        Text(isAdding ? "Adding…" : "Add Anything")
                        Spacer()
                    }
                }
                .disabled(
                    isAdding ||
                    selectedAppID == nil ||
                    capability.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                )
            } header: {
                Text("Add Anything")
            } footer: {
                Text("Enter the exact capability identifier accepted by Apple's Developer API. Adding a capability does not guarantee that an app can use its entitlement.")
            }

            if let selectedAppID {
                Section {
                    if selectedAppID.result.isEmpty {
                        Text("No server response yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(selectedAppID.result)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } header: {
                    Text("Server Response")
                }
            }
        }
        .navigationTitle("Experiments")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAppIDs()
        }
        .alert("Error", isPresented: $errorShow) {
            Button("OK".loc, action: {})
        } message: {
            Text(errorInfo)
        }
    }

    private func loadAppIDs() async {
        isLoading = true
        defer {
            isLoading = false
        }

        do {
            try await viewModel.fetchAppIDs()

            if selectedAppID == nil {
                selectedAppID = viewModel.appIDs.first
            }
        } catch {
            errorInfo = error.detailedDescription
            errorShow = true
        }
    }

    private func addAnything() async {
        guard let selectedAppID else {
            return
        }

        isAdding = true
        defer {
            isAdding = false
        }

        do {
            try await selectedAppID.addCapability(capability)
        } catch {
            errorInfo = error.detailedDescription
            errorShow = true
        }
    }
}
