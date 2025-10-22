//
//  ClientTabView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

// ClientTabView.swift
// ClientTabView.swift
import SwiftUI

struct ClientTabView: View {
    @EnvironmentObject var session: SessionManager
    @EnvironmentObject var cart: CartStore

    @StateObject private var socket = SocketService()
    @StateObject private var productsStore = ProductsStore()

    @State private var selected = 1
    @State private var didSetup = false

    var body: some View {
        TabView(selection: $selected) {
            // Carrito
            NavigationStack { ClientCartView() }
                .tabItem { Label("Carrito", systemImage: "cart") }
                .badge(cart.count)
                .tag(0)

            // Pedidos (GRID)
            NavigationStack { ClientOrdersGridView() }
                .tabItem { Label("Pedidos", systemImage: "list.bullet.rectangle") }
                .tag(1)

            // Perfil
            NavigationStack { ClientProfileView() }
                .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
                .tag(2)
        }
        .tint(.matcha)
        // 🔑 Inyecta los 2 env objects a TODO el árbol de tabs
        .environmentObject(socket)
        .environmentObject(productsStore)
        .onAppear {
            guard !didSetup else { return }
            socket.connect(jwt: "jwt_real", shopId: "tienda-1", role: .client)
            productsStore.bind(to: socket)
            didSetup = true
        }
    }
}

#Preview {
    ClientTabView()
        .environmentObject(SessionManager())
        .environmentObject(CartStore())
}

