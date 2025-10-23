//
//  ServerView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

// ServerTabView.swift
import SwiftUI

struct ServerTabView: View {
    @StateObject private var socket = SocketService()
    @StateObject private var products = ProductsStore()
    @StateObject private var orders = OrdersStore()

    var body: some View {
        TabView {
            NavigationStack { ServerProductsView() }
                .tabItem { Label("Productos", systemImage: "shippingbox") }

            NavigationStack { ServerOrdersListView() }   // tu lista de pedidos
                .tabItem { Label("Pedidos", systemImage: "tray.full") }

            NavigationStack { ServerProfileView() }
                .tabItem { Label("Perfil", systemImage: "person") }
        }
        .environmentObject(socket)
        .environmentObject(products)
        .environmentObject(orders)
        .onAppear {
            socket.connect(jwt: "jwt_server", shopId: "tienda-1", role: .server)
            products.bind(to: socket) // opcional si el server también escucha catálogo
            orders.bind(to: socket)   // << importante para recibir pedidos
        }
    }
}

#Preview {
    let session = SessionManager()
    session.isAuthenticated = true
    session.selectedRole = .server

    let socket = SocketService()
    let products = ProductsStore()
    let orders = OrdersStore()
    let sales = SalesStore()

    return ServerTabView()
        .environmentObject(session)
        .environmentObject(socket)
        .environmentObject(products)
        .environmentObject(orders)
        .environmentObject(sales)
}

