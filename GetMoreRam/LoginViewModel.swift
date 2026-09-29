//
//  LoginViewModel.swift
//  GetMoreRam
//
//  Created by s s on 2025/3/15.
//

import SwiftUI
import StosSign_API
import StosSign_Auth
import StosSign_Common

@MainActor
class LoginViewModel: ObservableObject {
    @Published var appleID = ""
    @Published var password = ""
    @Published var needVerificationCode = false
    @Published var verificationCode = ""
    @Published var loginModalShow = false
    @Published var teamSelectionShow = false
    @Published var isLoginInProgress = false
    @Published private(set) var isVerificationCodeSubmitting = false
    @Published var logs = UserDefaults.standard.string(
        forKey: "getMoreRam.authenticationLogs"
    ) ?? ""
    @Published var availableTeams: [Team] = []

    private let logsStorageKey = "getMoreRam.authenticationLogs"

    private var verificationCodeHandler: ((String?) -> Void)?
    private var isAuthenticationCancellationRequested = false

    /// Redacts sensitive values before they are displayed or saved in logs.
    private static func redactSensitiveData(_ text: String) -> String {
        let patterns: [(pattern: String, replacement: String)] = [
            (
                #"(?i)(["']?(?:oneTimePassword|localUserID|deviceUniqueIdentifier|deviceDescription|machineID|serialNumber|x-apple-i-md(?:-m|-info)?|authorization|password|cookie|session(?:Token|ID)?|appleID|email)["']?\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^,\]\}\s]+)"#,
                "$1\"[REDACTED]\""
            ),
            (
                #"(?i)\bBearer\s+[A-Za-z0-9._~+/-]+=*"#,
                "Bearer [REDACTED]"
            ),
            (
                #"(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#,
                "[REDACTED EMAIL]"
            )
        ]

        var redacted = text

        for item in patterns {
            guard let regex = try? NSRegularExpression(
                pattern: item.pattern
            ) else {
                continue
            }

            let range = NSRange(
                redacted.startIndex..<redacted.endIndex,
                in: redacted
            )

            redacted = regex.stringByReplacingMatches(
                in: redacted,
                range: range,
                withTemplate: item.replacement
            )
        }

        return redacted
    }

    private func appendSafeLog(_ text: String) {
        let safeText = Self.redactSensitiveData(text)
        logs.append(safeText + "\n")
        UserDefaults.standard.set(logs, forKey: logsStorageKey)
    }

    func clearLogs() {
        logs = ""
        UserDefaults.standard.removeObject(forKey: logsStorageKey)
    }

    func submitVerificationCode() {
        guard !isVerificationCodeSubmitting,
              let verificationCodeHandler else {
            return
        }

        self.verificationCodeHandler = nil
        isVerificationCodeSubmitting = true
        verificationCodeHandler(verificationCode)
    }

    func cancelAuthentication() {
        guard isLoginInProgress else {
            return
        }

        isAuthenticationCancellationRequested = true

        let handler = verificationCodeHandler
        verificationCodeHandler = nil
        needVerificationCode = false
        verificationCode = ""
        isVerificationCodeSubmitting = false

        handler?(nil)
    }

    func authenticate() async throws -> Bool {
        if isLoginInProgress {
            return false
        }

        logs = ""
        UserDefaults.standard.removeObject(forKey: logsStorageKey)

        isLoginInProgress = true
        isAuthenticationCancellationRequested = false

        func logging(text: String) {
            Task { @MainActor [weak self] in
                self?.appendSafeLog(text)
            }
        }

        AnisetteDataHelper.shared.loggingFunc = logging

        defer {
            verificationCodeHandler = nil
            appleID = ""
            password = ""
            needVerificationCode = false
            verificationCode = ""
            isLoginInProgress = false
            isVerificationCodeSubmitting = false
            isAuthenticationCancellationRequested = false
        }

        do {
            let anisetteData = try await AnisetteDataHelper.shared.getAnisetteData()

            let (account, session) = try await AppleAPI.shared.authenticate(
                appleID: appleID,
                password: password,
                anisetteData: anisetteData
            ) { [weak self] completionHandler in
                guard let self else {
                    completionHandler(nil)
                    return
                }

                self.prepareForVerification(using: completionHandler)
            }

            guard !isAuthenticationCancellationRequested else {
                throw CancellationError()
            }

            logging(text: "Successfully signed in")

            DataManager.shared.model.account = account
            DataManager.shared.model.session = session
            Keychain.shared.appleIDEmailAddress = appleID
            Keychain.shared.appleIDPassword = password

            let teams = try await fetchTeams(
                for: account,
                session: session
            )

            logging(text: "Successfully fetched teams")
            availableTeams = teams

            return true
        } catch {
            if isAuthenticationCancellationRequested {
                throw CancellationError()
            }

            print(Self.redactSensitiveData(String(describing: error)))
            throw error
        }
    }

    private func prepareForVerification(
        using handler: @escaping (String?) -> Void
    ) {
        guard !isAuthenticationCancellationRequested else {
            handler(nil)
            return
        }

        verificationCodeHandler = handler
        verificationCode = ""
        needVerificationCode = true
        isVerificationCodeSubmitting = false
    }

    func fetchTeams(
        for account: Account,
        session: AppleAPISession
    ) async throws -> [Team] {
        let fetchedTeams = try await AppleAPI.shared.fetchTeamsForAccount(
            account: account,
            session: session
        )

        guard !fetchedTeams.isEmpty else {
            throw "Unable to Fetch Team!"
        }

        return fetchedTeams
    }
}
