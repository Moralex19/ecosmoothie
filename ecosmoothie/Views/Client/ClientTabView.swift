//
//  ClientTabView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

// ClientTabView.swift
// ClientTabView.swift
import SwiftUI
import Combine

struct ClientTabView: View {
    @EnvironmentObject var session: SessionManager
    @EnvironmentObject var cart: CartStore

    @StateObject private var socket = SocketService()
    @StateObject private var productsStore = ProductsStore()

    @State private var selected = 1
    @State private var didSetup = false

    var body: some View {
        NavigationStack {
            TabView(selection: $selected) {
                // Carrito
                ClientCartView()
                    .environmentObject(socket)
                    .tabItem { Label("Carrito", systemImage: "cart") }
                    .badge(cart.count)
                    .tag(0)

                // Pedidos (GRID)
                ClientOrdersGridView()
                    .environmentObject(productsStore)
                    .tabItem { Label("Pedidos", systemImage: "list.bullet.rectangle") }
                    .tag(1)

                // Perfil
                ClientProfileView()
                    .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
                    .tag(2)
            }
            .tint(.matcha)
            .onAppear {
                guard !didSetup else { return }
                socket.connect(jwt: "jwt_real", shopId: "tienda-1", role: .client)
                productsStore.bind(to: socket)

                let ap = UITabBarAppearance()
                ap.configureWithOpaqueBackground()
                ap.backgroundColor = UIColor(Color.almond)
                UITabBar.appearance().standardAppearance = ap
                if #available(iOS 15.0, *) { UITabBar.appearance().scrollEdgeAppearance = ap }
                UITabBar.appearance().isTranslucent = false

                didSetup = true
            }
            .navigationTitle(tabTitle)
        }
    }

    private var tabTitle: String {
        switch selected {
        case 0: return "Carrito"
        case 1: return "Tomar pedidos"
        default: return "Perfil"
        }
    }
}

#Preview {
    ClientTabView()
        .environmentObject(SessionManager())
        .environmentObject(CartStore())
}
