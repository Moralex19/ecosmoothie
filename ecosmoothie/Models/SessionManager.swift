//
//  SessionManager.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

import Foundation
import SwiftUI
import Combine

enum AppRole: String, CaseIterable, Codable {
    case client = "Cliente"
    case server = "Servidor"
}

final class SessionManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var userEmail: String? = nil
    @Published var selectedRole: AppRole = .client

    /// DEMO: login hardcodeado (no producción)
    func login(email: String, password: String, role: AppRole) async throws {
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s simulando red

        guard email.lowercased() == "unach@gmail.com", password == "12345" else {
            throw NSError(
                domain: "Auth",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Credenciales inválidas"]
            )
        }

        await MainActor.run {
            self.userEmail = email
            self.selectedRole = role
            self.isAuthenticated = true
        }
    }

    func logout() {
        userEmail = nil
        isAuthenticated = false
        selectedRole = .client
    }
}
