//
//  SettingsView.swift
//  GetMoreRam
//
//  Created by s s on 2025/3/14.
//

import SwiftUI
import UniformTypeIdentifiers
import StosSign_API
import StosSign_Auth
import StosSign_Common

struct SettingsView: View {
    @State var email = ""
    @State var teamId = ""
    @StateObject var viewModel: LoginViewModel
    @EnvironmentObject private var sharedModel: SharedModel

    @AppStorage("appTheme") private var appTheme = "system"

    @State private var errorShow = false
    @State private var errorInfo = ""
    @State private var importResultShow = false
    @State private var importResultInfo = ""
    @State private var isImportingSideStoreAccount = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    if sharedModel.isLogin {
                        LabeledContent("Email") {
                            Text(email)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }

                        LabeledContent("Team ID") {
                            Text(teamId)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    } else {
                        Button {
                            viewModel.loginModalShow = true
                        } label: {
                            Label("Sign in", systemImage: "person.crop.circle.badge.checkmark")
                        }

                        Button {
                            isImportingSideStoreAccount = true
                        } label: {
                            Label(
                                "Import SideStore Account",
                                systemImage: "square.and.arrow.down"
                            )
                        }
                    }
                } header: {
                    Text("Account")
                } footer: {
                    if sharedModel.isLogin {
                        Text("You are signed in with the selected Apple Developer team.")
                    } else {
                        Text("Sign in with an Apple Account or import a SideStore account.")
                    }
                }

                Section {
                    NavigationLink {
                        LogsView(viewModel: viewModel)
                    } label: {
                        Label(
                            "Authentication Logs",
                            systemImage: "doc.text.magnifyingglass"
                        )
                    }

                    NavigationLink {
                        ExperimentsView()
                    } label: {
                        Label(
                            "Experiments",
                            systemImage: "flask"
                        )
                    }
                } header: {
                    Text("Tools")
                } footer: {
                    Text("View diagnostic activity or manage experimental App ID capabilities.")
                }

                Section {
                    Picker(selection: $appTheme) {
                        Label("System", systemImage: "iphone")
                            .tag("system")

                        Label("Light", systemImage: "sun.max.fill")
                            .tag("light")

                        Label("Dark", systemImage: "moon.fill")
                            .tag("dark")
                    } label: {
                        Label(
                            "Appearance",
                            systemImage: "paintpalette"
                        )
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Theme")
                } footer: {
                    Text("Choose whether GetMoreRam follows your device appearance or uses Light or Dark mode.")
                }

                Section {
                    HStack {
                        Text("Anisette Server URL")
                        Spacer()

                        TextField(
                            "Server URL",
                            text: $sharedModel.anisetteServerURL
                        )
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    }
                } header: {
                    Text("Anisette")
                } footer: {
                    Text("The Anisette server provides data used during Apple authentication.")
                }

                Section {
                    Button(role: .destructive) {
                        cleanUp()
                    } label: {
                        Label(
                            "Clean Up Keychain",
                            systemImage: "key.slash"
                        )
                    }
                } footer: {
                    Text("If something went wrong during sign in, try cleaning up the keychain, reopening the app and signing in again. If you use SideStore and are already signed in, you can export your SideStore account from SideStore settings and import it here.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $errorShow) {
                Button("OK".loc, action: {})
            } message: {
                Text(errorInfo)
            }
            .alert("SideStore Account", isPresented: $importResultShow) {
                Button("OK".loc, action: {})
            } message: {
                Text(importResultInfo)
            }
            .fileImporter(
                isPresented: $isImportingSideStoreAccount,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                importSideStoreAccount(result)
            }
            .sheet(
                isPresented: $viewModel.loginModalShow,
                onDismiss: {
                    viewModel.cancelAuthentication()
                }
            ) {
                loginModal
            }
            .sheet(isPresented: $viewModel.teamSelectionShow) {
                teamSelectionView
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    var loginModal: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Apple ID", text: $viewModel.appleID)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(viewModel.isLoginInProgress)
                } header: {
                    Text("Apple ID")
                }

                Section {
                    SecureField("Password", text: $viewModel.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(viewModel.isLoginInProgress)
                } header: {
                    Text("Password")
                }

                if viewModel.needVerificationCode {
                    Section {
                        TextField(
                            "Six-digit verification code",
                            text: $viewModel.verificationCode
                        )
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .disabled(viewModel.isVerificationCodeSubmitting)
                    } header: {
                        Text("Verification Code")
                    } footer: {
                        Text("Enter the verification code provided by Apple.")
                    }
                }

                Section {
                    Button {
                        Task {
                            await loginButtonClicked()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isLoginInProgress {
                                ProgressView()
                                    .padding(.trailing, 6)
                            }

                            Text(viewModel.needVerificationCode ? "Submit Code" : "Continue")
                            Spacer()
                        }
                    }
                    .disabled(continueButtonDisabled)
                }

                Section {
                    if viewModel.logs.isEmpty {
                        Text("Authentication activity will appear here.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(viewModel.logs)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    NavigationLink {
                        LogsView(viewModel: viewModel)
                    } label: {
                        Label(
                            "View All Logs",
                            systemImage: "doc.text.magnifyingglass"
                        )
                    }
                } header: {
                    Text("Debugging")
                } footer: {
                    Text("Sensitive values are redacted from the app's authentication logs.")
                }
            }
            .navigationTitle("Sign in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .cancel) {
                        viewModel.cancelAuthentication()
                        viewModel.loginModalShow = false
                    }
                    .disabled(viewModel.isLoginInProgress && viewModel.needVerificationCode == false)
                }
            }
        }
        .onAppear {
            if let savedEmail = Keychain.shared.appleIDEmailAddress,
               let savedPassword = Keychain.shared.appleIDPassword {
                viewModel.appleID = savedEmail
                viewModel.password = savedPassword
            }
        }
    }

    var teamSelectionView: some View {
        NavigationView {
            List {
                ForEach(
                    Array(viewModel.availableTeams.enumerated()),
                    id: \.offset
                ) { _, team in
                    Button {
                        selectTeam(team)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(team.name)
                                .foregroundStyle(.primary)

                            Text("\(team.identifier) · \(teamTypeDescription(team.type))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                }
            }
            .navigationTitle("Choose Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .cancel) {
                        cancelTeamSelection()
                    }
                }
            }
        }
    }

    func loginButtonClicked() async {
        do {
            if viewModel.needVerificationCode {
                viewModel.submitVerificationCode()
                return
            }

            let result = try await viewModel.authenticate()

            if result {
                await MainActor.run {
                    viewModel.loginModalShow = false
                    email = sharedModel.account?.appleID ?? viewModel.appleID
                    teamId = ""
                }

                if viewModel.availableTeams.count == 1,
                   let team = viewModel.availableTeams.first {
                    await MainActor.run {
                        selectTeam(team)
                    }
                } else {
                    try? await Task.sleep(nanoseconds: 300_000_000)

                    await MainActor.run {
                        viewModel.teamSelectionShow = true
                    }
                }
            }
        } catch is CancellationError {
            return
        } catch {
            errorInfo = error.detailedDescription
            errorShow = true
        }
    }

    private var continueButtonDisabled: Bool {
        if viewModel.needVerificationCode {
            return viewModel.isVerificationCodeSubmitting ||
                viewModel.verificationCode
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
        }

        return viewModel.isLoginInProgress
    }

    func cleanUp() {
        Keychain.shared.adiPb = nil
        Keychain.shared.identifier = nil
        Keychain.shared.appleIDPassword = nil
        Keychain.shared.appleIDEmailAddress = nil

        AnisetteDataHelper.shared.resetClientInfo()

        sharedModel.session = nil
        sharedModel.account = nil
        sharedModel.team = nil
        sharedModel.isLogin = false

        viewModel.availableTeams = []
        viewModel.teamSelectionShow = false

        email = ""
        teamId = ""
    }

    func importSideStoreAccount(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                throw "No file selected."
            }

            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let account = try SideStoreAccountImporter.importAccount(from: data)

            viewModel.appleID = account.email
            viewModel.password = account.password

            sharedModel.session = nil
            sharedModel.account = nil
            sharedModel.team = nil
            sharedModel.isLogin = false

            viewModel.availableTeams = []
            viewModel.teamSelectionShow = false

            email = account.email
            teamId = ""

            importResultInfo = "Imported \(account.email).\nTap \"Sign In\" to continue."
            importResultShow = true
        } catch {
            errorInfo = error.detailedDescription
            errorShow = true
        }
    }

    func selectTeam(_ team: Team) {
        sharedModel.team = team
        sharedModel.isLogin = true
        email = sharedModel.account?.appleID ?? email
        teamId = team.identifier

        viewModel.availableTeams = []
        viewModel.teamSelectionShow = false
    }

    func cancelTeamSelection() {
        viewModel.availableTeams = []
        viewModel.teamSelectionShow = false

        sharedModel.session = nil
        sharedModel.account = nil
        sharedModel.team = nil
        sharedModel.isLogin = false

        email = ""
        teamId = ""
    }

    func teamTypeDescription(_ type: TeamType) -> String {
        switch type {
        case .free:
            return "Free"
        case .individual:
            return "Individual"
        case .organization:
            return "Organization"
        case .unknown:
            return "Unknown"
        }
    }
}

struct LogsView: View {
    @ObservedObject var viewModel: LoginViewModel

    var body: some View {
        Form {
            Section {
                if viewModel.logs.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)

                        Text("No Logs Yet")
                            .font(.headline)

                        Text("Authentication and server activity will appear here when available.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    Text(viewModel.logs)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } header: {
                Text("Activity")
            } footer: {
                Text("Logs are stored on this device after sensitive values are redacted. Review them before sharing.")
            }

            Section {
                Button(role: .destructive) {
                    viewModel.clearLogs()
                } label: {
                    Label("Clear Logs", systemImage: "trash")
                }
                .disabled(viewModel.logs.isEmpty)
            }
        }
        .navigationTitle("Authentication Logs")
        .navigationBarTitleDisplayMode(.inline)
    }
}
