//
//  SessionManager.swift
//  ecosmoothie
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
    // Estado de sesión / UI
    @Published var isAuthenticated = false
    @Published var userEmail: String? = nil
    @Published var selectedRole: AppRole = .client
    @Published var isAuthenticating = false
    @Published var viewResetID = UUID()     // ← resetea pilas de navegación

    // Datos que usará el SocketService
    @Published var jwt: String = ""
    @Published var shopId: String = ""

    /// Conveniencia: hay sesión iniciada
    var isLoggedIn: Bool { isAuthenticated }

    /// Conveniencia: mapeo a `SocketRole` (la enum que tienes en SocketService)
    var socketRole: SocketRole? {
        guard isAuthenticated else { return nil }
        return (selectedRole == .client) ? .client : .server
    }

    // MARK: - Login

    func login(email: String, password: String, role: AppRole) async throws {
        isAuthenticating = true
        defer { isAuthenticating = false }

        // Simulación de red
        try await Task.sleep(nanoseconds: 200_000_000)

        guard email.lowercased() == "ecosmoothie@gmail.com", password == "12345" else {
            throw NSError(
                domain: "Auth",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Credenciales inválidas"]
            )
        }

        // ✅ Datos de sesión
        userEmail    = email
        selectedRole = role
        isAuthenticated = true

        // ✅ Configurar credenciales para el socket según rol
        switch role {
        case .client:
            jwt    = "jwt_real"   // el que usas en el server para cliente
            shopId = "tienda-1"

        case .server:
            jwt    = "jwt_server" // el que usas en el server para server
            shopId = "tienda-1"
        }

        // reset de navegación
        viewResetID = UUID()
    }

    // MARK: - Logout

    func logout() {
        userEmail = nil
        isAuthenticated = false
        selectedRole = .client

        // limpiar datos del socket
        jwt = ""
        shopId = ""

        viewResetID = UUID()      // ← reset al cerrar sesión
    }
}
