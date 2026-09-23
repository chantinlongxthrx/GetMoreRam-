//
//  AppIDViewModel.swift
//  GetMoreRam
//
//  Created by s s on 2025/3/15.
//

import SwiftUI
import StosSign_API
import StosSign_Auth
import StosSign_Common

class AppIDModel : ObservableObject, Hashable {
    static func == (lhs: AppIDModel, rhs: AppIDModel) -> Bool { lhs === rhs }
    func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }

    var appID: AppID
    @Published var bundleID: String
    @Published var result: String = ""
    @Published var lastCapability: String = ""

    init(appID: AppID) {
        self.appID = appID
        bundleID = appID.bundleIdentifier
    }

    func addCapability(_ capability: String) async throws {
        guard let team = DataManager.shared.model.team,
              let session = DataManager.shared.model.session else {
            throw "Please Login First"
        }

        let identifier = capability.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty else {
            throw "Capability identifier cannot be empty."
        }

        let response = try await AppleAPI.shared.updateAppID(
            appID,
            capabilities: [identifier],
            team: team,
            session: session
        )

        await MainActor.run {
            lastCapability = identifier
            result = "\(response)"
        }
    }

    func addIncreasedMemory() async throws {
        try await addCapability("INCREASED_MEMORY_LIMIT")
    }
}

class AppIDViewModel : ObservableObject {
    @Published var appIDs : [AppIDModel] = []

    func fetchAppIDs() async throws {
        guard let team = DataManager.shared.model.team, let session = DataManager.shared.model.session else {
            throw "Please Login First"
        }

        let ids = try await AppleAPI.shared.fetchAppIDsForTeam(team: team, session: session)
        await MainActor.run {
            appIDs.removeAll()
            for id in ids {
                appIDs.append(AppIDModel(appID: id))
            }
        }
    }
}
