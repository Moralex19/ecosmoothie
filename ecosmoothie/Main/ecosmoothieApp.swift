//
//  ecosmoothieApp.swift
//  ecosmoothie
//

import SwiftUI

@main
struct EcosmoothieApp: App {
    @StateObject private var session  = SessionManager()
    @StateObject private var cart     = CartStore()
    @StateObject private var products = ProductsStore()
    @StateObject private var socket   = SocketService()
    @StateObject private var orders   = OrdersStore()
    @StateObject private var sales    = SalesStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(cart)
                .environmentObject(products)
                .environmentObject(socket)
                .environmentObject(orders)
                .environmentObject(sales)
        }
    }
}

