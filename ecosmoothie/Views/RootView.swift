//
//  RootView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

// RootView.swift
import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: SessionManager
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                SplashScreen {
                    // Evita crash: transición en el MainActor
                    Task { @MainActor in
                        withAnimation(.easeInOut) { showSplash = false }
                    }
                }
            } else {
                if session.isAuthenticated {
                    NavigationStack {
                        Text("Home (autenticado)")
                            .font(.largeTitle)
                            .padding()
                    }
                } else {
                    // Asegura stack de navegación al entrar a Auth
                    NavigationStack { AuthView() }
                }
            }
        }
    }
}

#Preview {
    RootView().environmentObject(SessionManager())
}

