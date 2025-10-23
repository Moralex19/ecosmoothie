//
//  RootView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

// RootView.swift
// RootView.swift
import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: SessionManager
    @EnvironmentObject var cart: CartStore
    @State private var showSplash = true

    var body: some View {
        ZStack(alignment: .top) {
            // Contenido
            Group {
                if showSplash {
                    SplashScreen {
                        Task { @MainActor in
                            withAnimation(.easeInOut) { showSplash = false }
                        }
                    }
                } else {
                    // RootView.swift (fragmento dentro del else autenticado)
                    if session.selectedRole == .client {
                        ClientTabView()
                            .environmentObject(CartStore())
                            .environmentObject(ProductsStore())
                            .environmentObject(SocketService())
                    } else {
                        ServerTabView()
                            .environmentObject(SocketService())
                            .environmentObject(ProductsStore())
                            .environmentObject(OrdersStore())
                            .environmentObject(SalesStore()) // o con path para SQLite
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
        .disabled(session.isAuthenticating) // opcional: evitar taps durante login
    }
}

#Preview {
    RootView()
        .environmentObject(SessionManager())
        .environmentObject(CartStore())
}
