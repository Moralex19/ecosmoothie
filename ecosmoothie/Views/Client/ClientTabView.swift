//
//  ClientTabView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

// ClientTabView.swift
import SwiftUI

struct ClientTabView: View {
    @EnvironmentObject var session: SessionManager
    @EnvironmentObject var cart: CartStore

    @StateObject private var socket = SocketService()
    @StateObject private var productsStore = ProductsStore()
    @StateObject private var coord = ClientTabCoordinator()

    @State private var didSetup = false

    var body: some View {
        ZStack {
            // Fondo de la app si quieres un color global
            Color(.systemBackground)

            VStack(spacing: 0) {

                // (Opcional) encabezado propio
                HStack {
                    Text(title(for: coord.currentTab))
                        .font(.largeTitle.bold())
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Contenido: usamos TabView sin su barra nativa
                TabView(selection: $coord.currentTab) {
                    ClientCartView()
                        .tag(ClientTab.cart)

                    ClientOrdersGridView()
                        .tag(ClientTab.orders)

                    ClientProfileView()
                        .tag(ClientTab.profile)
                }
                .tabViewStyle(.page(indexDisplayMode: .never)) // sin dots
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Barra inferior personalizada — empuja el contenido
                ClientCustomTabBar(
                    current: $coord.currentTab,
                    cartBadge: cart.count,
                    onTap: { coord.navigate(to: $0) }
                )
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .environmentObject(socket)
        .environmentObject(productsStore)
        .task {
            guard !didSetup else { return }
            socket.connect(jwt: "jwt_real", shopId: "tienda-1", role: .client)
            productsStore.bind(to: socket)
            didSetup = true
        }
    }

    private func title(for tab: ClientTab) -> String {
        switch tab {
        case .cart: return "Carrito"
        case .orders: return "Tomar pedidos"
        case .profile: return "Perfil"
        }
    }
}

#Preview {
    ClientTabView()
        .environmentObject(SessionManager())
        .environmentObject(CartStore())
}
