//
//  RootView.swift
//  ecosmoothie
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: SessionManager
    @EnvironmentObject var cart: CartStore
    @EnvironmentObject var products: ProductsStore
    @EnvironmentObject var socket: SocketService
    @EnvironmentObject var orders: OrdersStore
    @EnvironmentObject var sales: SalesStore

    @State private var showSplash = true

    // MARK: - Manejo del WebSocket según sesión + rol
    private func updateSocket() {
        // Si NO hay sesión → desconectamos y listo
        guard session.isAuthenticated else {
            socket.disconnect()
            return
        }

        // Mapear AppRole -> SocketRole
        let socketRole: SocketRole = (session.selectedRole == .client) ? .client : .server

        // DEMO: mismos datos para ambos roles (ajusta si luego quieres JWT real)
        let jwt    = (socketRole == .client) ? "jwt_real"   : "jwt_server"
        let shopId = "tienda-1"

        // Evitar conexiones viejas / dobles
        socket.disconnect()

        socket.connect(
            jwt: jwt,
            shopId: shopId,
            role: socketRole
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if showSplash {
                    SplashScreen {
                        withAnimation(.easeInOut) { showSplash = false }
                    }
                } else {
                    if !session.isAuthenticated {
                        // LOGIN: el .id va en el contenedor para resetear la pila
                        NavigationStack {
                            AuthView()
                        }
                        .id(session.viewResetID) // ← clave para logout limpio
                    } else {
                        switch session.selectedRole {
                        case .client:
                            ClientTabView()
                                .environmentObject(cart)
                                .environmentObject(products)
                                .environmentObject(socket)
                                .id(session.viewResetID) // ← recrea jerarquía al login/logout

                        case .server:
                            ServerTabView()
                                .environmentObject(socket)
                                .environmentObject(products)
                                .environmentObject(orders)
                                .environmentObject(sales)
                                .id(session.viewResetID) // ← idem para servidor
                        }
                    }
                }
            }

            if session.isAuthenticating {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(.matcha)
                    .frame(height: 2)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .disabled(session.isAuthenticating)

        // MARK: - Hooks de ciclo de vida
        .onAppear {
            // Vincular stores UNA VEZ (los sinks internos se limpian en cada bind)
            products.bind(to: socket)
            orders.bind(to: socket)

            // Ajustar conexión inicial del socket según cómo esté la sesión
            updateSocket()
        }
        // Cuando se loguea / hace logout
        .onChange(of: session.isAuthenticated) { _, _ in
            updateSocket()
        }
        // Cuando cambia de rol (cliente/servidor)
        .onChange(of: session.selectedRole) { _, _ in
            updateSocket()
        }
    }
}


// MARK: - Previews
#Preview("Sin autenticar") {
    RootView()
        .environmentObject(mockSession(auth: false, role: .client))
        .environmentObject(CartStore())
        .environmentObject(ProductsStore())
        .environmentObject(SocketService())
        .environmentObject(OrdersStore())
        .environmentObject(SalesStore())
}

#Preview("Autenticado Cliente") {
    RootView()
        .environmentObject(mockSession(auth: true, role: .client))
        .environmentObject(CartStore())
        .environmentObject(ProductsStore())
        .environmentObject(SocketService())
        .environmentObject(OrdersStore())
        .environmentObject(SalesStore())
}

#Preview("Autenticado Servidor") {
    RootView()
        .environmentObject(mockSession(auth: true, role: .server))
        .environmentObject(CartStore())
        .environmentObject(ProductsStore())
        .environmentObject(SocketService())
        .environmentObject(OrdersStore())
        .environmentObject(SalesStore())
}

// Helper para previews
private func mockSession(auth: Bool, role: AppRole) -> SessionManager {
    let s = SessionManager()
    s.isAuthenticated = auth
    s.selectedRole = role
    return s
}
