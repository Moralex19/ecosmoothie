//
//  ClientProfileView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

// ClientProfileView.swift
import SwiftUI

struct ClientProfileView: View {
    @EnvironmentObject var session: SessionManager
    @State private var cartsSoldToday: Int = 0 // “total de carritos vendidos por día” (demo)

    var body: some View {
        NavigationStack {
            Form {
                Section("Cuenta") {
                    HStack {
                        Text("Correo")
                        Spacer()
                        Text(session.userEmail ?? "—")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Métricas") {
                    HStack {
                        Text("Carritos vendidos hoy")
                        Spacer()
                        Text("\(cartsSoldToday)")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.matcha)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        session.logout()
                    } label: {
                        Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .scrollContentBackground(.automatic)
            .navigationTitle("Perfil")
            .onAppear {
                // Demo: valor ficticio
                cartsSoldToday = Int.random(in: 3...12)
            }
        }
    }
}

#Preview {
    ClientProfileView().environmentObject(SessionManager())
}

