//
//  RootView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

// RootView.swift
import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: SessionManager
    @EnvironmentObject var cart: CartStore
    @EnvironmentObject var products: ProductsStore
    @EnvironmentObject var socket: SocketService
    // Estos dos solo los usará el modo Servidor si los inyectas desde el App
    @EnvironmentObject var orders: OrdersStore
    @EnvironmentObject var sales: SalesStore

    @State private var showSplash = true

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if showSplash {
                    SplashScreen {
                        Task { @MainActor in
                            withAnimation(.easeInOut) { showSplash = false }
                        }
                    }
                } else {
                    // 1) Primero, gate por autenticación
                    if !session.isAuthenticated {
                        NavigationStack { AuthView() }
                    } else {
                        // 2) Ya autenticado: decide por rol
                        switch session.selectedRole {
                        case .client:
                            ClientTabView()
                                // Usa los EnvironmentObject ya inyectados por la app
                                .environmentObject(cart)
                                .environmentObject(products)
                                .environmentObject(socket)

                        case .server:
                            ServerTabView()
                                .environmentObject(socket)
                                .environmentObject(products)
                                .environmentObject(orders)
                                .environmentObject(sales)
                        }
                    }
                }
            }

            // Barra de progreso fina mientras se hace login / refresh de sesión
            if session.isAuthenticating {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(.matcha)
                    .frame(height: 2)
                    .padding(.top, 0)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // Evita toques mientras se autentica (opcional)
        .disabled(session.isAuthenticating)
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
