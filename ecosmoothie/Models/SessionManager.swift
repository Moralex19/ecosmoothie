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
    case client  = "Cliente"
    case server  = "Servidor"
}

@MainActor
final class SessionManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userEmail: String? = nil
    @Published var selectedRole: AppRole = .client
    @Published var isAuthenticating = false   // ← NUEVO

    func login(email: String, password: String, role: AppRole) async throws {
        isAuthenticating = true
        defer { isAuthenticating = false }

        try await Task.sleep(nanoseconds: 200_000_000)
        guard email.lowercased() == "unach@gmail.com", password == "12345" else {
            throw NSError(domain: "Auth", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Credenciales inválidas"])
        }
        userEmail = email
        selectedRole = role
        isAuthenticated = true
    }

    func logout() {
        userEmail = nil
        isAuthenticated = false
        selectedRole = .client
    }
}
