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
                        .id(session.viewResetID)         // ← clave para logout limpio
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
                                .id(session.viewResetID) // ← idem por si usas servidor
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
