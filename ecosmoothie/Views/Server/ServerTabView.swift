//
//  ServerView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

// ServerTabView.swift
import SwiftUI

struct ServerTabView: View {
    // Stores/servicios
    @StateObject private var socket   = SocketService()
    @StateObject private var products = ProductsStore()
    @StateObject private var orders   = OrdersStore()
    @StateObject private var sales    = SalesStore()

    // Coordinador de tabs (usa el nombre NUEVO)
    @StateObject private var coord = ServerMainCoordinator()
    @State private var didSetup = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
            VStack(spacing: 0) {
                // Header (opcional)
                HStack {
                    Text(title(for: coord.current)).font(.largeTitle.bold())
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Contenido por tab
                Group {
                    switch coord.current {
                    case .products:
                        NavigationStack { ServerProductsView() }
                    case .orders:
                        NavigationStack { ServerOrdersListView() }
                    case .profile:
                        NavigationStack { ServerProfileView() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Barra inferior personalizada
                ServerCustomTabBar(
                    current: $coord.current,
                    pendingBadge: orders.pendingCount,
                    onTap: { coord.navigate(to: $0) }
                )
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .environmentObject(socket)
        .environmentObject(products)
        .environmentObject(orders)
        .environmentObject(sales)
        .task {
            guard !didSetup else { return }
            socket.connect(jwt: "jwt_server", shopId: "tienda-1", role: .server)
            products.bind(to: socket)
            orders.bind(to: socket)
            didSetup = true
        }
    }

    private func title(for tab: ServerMainTab) -> String {
        switch tab {
        case .products: return "Productos"
        case .orders:   return "Pedidos"
        case .profile:  return "Perfil"
        }
    }
}


#Preview {
    let session = SessionManager()
    session.isAuthenticated = true
    session.selectedRole = .server

    return ServerTabView()
        .environmentObject(session)
}
