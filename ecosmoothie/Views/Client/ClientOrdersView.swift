//
//  ClientOrdersView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

import SwiftUI

struct ClientOrdersView: View {
    @Binding var cartCount: Int

    // Demo de productos simples
    private let demoProducts = [
        ("Licuado Fresa", 45.0),
        ("Licuado Mango", 48.0),
        ("Licuado Plátano", 40.0)
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(demoProducts, id: \.0) { prod in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(prod.0).font(.headline)
                            Text(String(format: "$ %.2f", prod.1))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            cartCount += 1 // sumar al carrito (demo)
                        } label: {
                            Text("Añadir")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.pistache))
                                .foregroundStyle(.white)
                        }
                    }
                    .listRowBackground(Color.almond.opacity(0.35))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.almond.opacity(0.15))
            .navigationTitle("Tomar pedidos")
        }
    }
}

#Preview {
    ClientOrdersView(cartCount: .constant(0))
}
