//
//  ServerProductsView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 22/10/25.
//

// ServerProductsView.swift
import SwiftUI

struct ServerProductsView: View {
    @EnvironmentObject var products: ProductsStore
    @EnvironmentObject var socket: SocketService

    @State private var name: String = ""
    @State private var imageName: String = "fresa2"   // asset por defecto

    var body: some View {
        List {
            // Alta rápida de producto
            Section("Nuevo producto") {
                TextField("Nombre", text: $name)
                TextField("Imagen (asset)", text: $imageName)

                Button {
                    // 1) Agrega localmente
                    let p = Product(
                        id: UUID().uuidString,
                        name: name.isEmpty ? "Nuevo" : name,
                        imageName: imageName.isEmpty ? "fresa2" : imageName
                    )
                    products.appendLocal(p)

                    // 2) Empuja catálogo completo a los clientes
                    socket.sendCatalog(products.products)

                    // 3) Limpia form
                    name = ""
                    imageName = "fresa2"
                } label: {
                    Label("Agregar", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }

            // Catálogo actual
            Section("Catálogo actual") {
                ForEach(products.products) { p in
                    HStack {
                        Image(p.imageName)
                            .resizable().scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text(p.name)
                        Spacer()

                        // Eliminar individual
                        Button(role: .destructive) {
                            if let idx = products.products.firstIndex(where: { $0.id == p.id }) {
                                products.removeLocal(at: IndexSet(integer: idx))
                                socket.sendCatalog(products.products)
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .onDelete { offsets in
                    products.removeLocal(at: offsets)
                    socket.sendCatalog(products.products)
                }
            }
        }
        .navigationTitle("Productos")
    }
}

#Preview {
    let store = ProductsStore()
    store._setPreviewProducts([
        .init(id: "p-cafe",    name: "Café",    imageName: "cafe2"),
        .init(id: "p-fresa",   name: "Fresa",   imageName: "fresa2"),
    ])
    return NavigationStack {
        ServerProductsView()
            .environmentObject(store)
            .environmentObject(SocketService())
    }
}
