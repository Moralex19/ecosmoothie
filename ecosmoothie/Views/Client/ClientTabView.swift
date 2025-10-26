// ClientTabView.swift
import SwiftUI

struct ClientTabView: View {
    @EnvironmentObject var session: SessionManager
    @EnvironmentObject var cart: CartStore

    // Mantén tus estados/servicios tal como los tienes:
    @StateObject private var socket = SocketService()
    @StateObject private var productsStore = ProductsStore()
    @StateObject private var coord = ClientTabCoordinator()

    @State private var didSetup = false

    // Paths independientes por pestaña (para una navegación sólida)
    @State private var cartPath = NavigationPath()
    @State private var ordersPath = NavigationPath()
    @State private var profilePath = NavigationPath()

    var body: some View {
        ZStack {
            Color(.systemBackground)

            VStack(spacing: 0) {
                // Título por pestaña (igual a tu UX)
                HStack {
                    Text(title(for: coord.currentTab))
                        .font(.largeTitle.bold())
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // PESTAÑAS
                TabView(selection: $coord.currentTab) {

                    // CARRO
                    NavigationStack(path: $cartPath) {
                        ClientCartView()              // 👈 ESTA es tu vista de carrito
                    }
                    .tag(ClientTab.cart)

                    // PEDIDOS (grilla de productos)
                    NavigationStack(path: $ordersPath) {
                        ClientOrdersGridView()
                    }
                    .tag(ClientTab.orders)

                    // PERFIL
                    NavigationStack(path: $profilePath) {
                        ClientProfileView()           // 👈 ESTA es tu vista de perfil
                    }
                    .tag(ClientTab.profile)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Barra inferior personalizada (la tuya)
                ClientCustomTabBar(
                    current: $coord.currentTab,
                    cartBadge: cart.count,
                    onTap: { coord.navigate(to: $0) }
                )
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        // Tus objetos de entorno para hijos que lo necesitan
        .environmentObject(socket)
        .environmentObject(productsStore)
        .environmentObject(coord)

        // Conexión/Bind inicial (igual que tenías)
        .task {
            guard !didSetup else { return }
            socket.connect(jwt: "jwt_real", shopId: "tienda-1", role: .client)
            productsStore.bind(to: socket)
            didSetup = true
        }

        // Limpieza al cerrar sesión (evita trabas)
        .onChange(of: session.isAuthenticated) { loggedIn in
            if !loggedIn {
                socket.disconnect()
                productsStore.clear()
                didSetup = false
                // resetea navegación de tabs
                cartPath = .init()
                ordersPath = .init()
                profilePath = .init()
                coord.currentTab = .orders
            }
        }

        // Fuerza reconstrucción limpia cuando cambie el viewResetID
        .id(session.viewResetID)
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
