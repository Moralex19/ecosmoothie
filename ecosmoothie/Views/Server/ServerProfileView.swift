//
//  ServerProfileView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 22/10/25.
//

// ServerProfileView.swift
import SwiftUI

struct ServerProfileView: View {
    @EnvironmentObject var session: SessionManager
    @EnvironmentObject var sales: SalesStore

    var body: some View {
        List {
            Section("Ventas") {
                HStack {
                    Text("Hoy")
                    Spacer()
                    Text(sales.totalToday, format: .currency(code: "USD"))
                        .foregroundStyle(Color.matcha) // 👈 usa Color.matcha
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Semana")
                    Spacer()
                    Text(sales.totalThisWeek, format: .currency(code: "USD"))
                        .foregroundStyle(Color.matcha) // 👈 usa Color.matcha
                        .fontWeight(.semibold)
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
        //.navigationTitle("Perfil")
        // refresca los totales cuando aparece
        .onAppear {
            sales.refreshAggregates()   // 👈 ahora es accesible
        }
    }
}

