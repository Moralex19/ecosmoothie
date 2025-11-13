//
//  ContentView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    RootView()
        .environmentObject(SessionManager())
        .environmentObject(CartStore())
        .environmentObject(ProductsStore())
        .environmentObject(SocketService())
        .environmentObject(OrdersStore())
        .environmentObject(SalesStore())
}
