//  ProductStore.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

import Foundation
import Combine
import SwiftUI

/// Catálogo compartido. En cliente se alimenta por sockets (`catalog.updated`);
/// en servidor puedes mutarlo localmente (append/remove) y luego emitir por socket.
@MainActor
final class ProductsStore: ObservableObject {
    @Published private(set) var products: [Product] = [
        // Sabores base (smoothies)
        .init(id: "p-cafe",
              name: "Café",
              imageName: "cafe2",
              price: 15,
              kind: .smoothie),

        .init(id: "p-durazno",
              name: "Durazno",
              imageName: "durazno2",
              price: 15,
              kind: .smoothie),

        .init(id: "p-fresa",
              name: "Fresa",
              imageName: "fresa2",
              price: 15,
              kind: .smoothie),

        .init(id: "p-kiwi",
              name: "Kiwi",
              imageName: "kiwi2",
              price: 15,
              kind: .smoothie),

        .init(id: "p-mango",
              name: "Mango",
              imageName: "mango2",
              price: 15,
              kind: .smoothie),

        // Ingredientes de ejemplo (no necesitan foto)
        .init(id: "i-cereza",
              name: "Cereza",
              imageName: "",
              price: 1,
              kind: .ingredient),

        .init(id: "i-frambuesa",
              name: "Frambuesa",
              imageName: "",
              price: 3,
              kind: .ingredient),

        .init(id: "i-picafresa",
              name: "Picafresa",
              imageName: "",
              price: 4,
              kind: .ingredient),

        .init(id: "i-dulce",
              name: "Dulce",
              imageName: "",
              price: 5,
              kind: .ingredient)
    ]

    private var bag = Set<AnyCancellable>()

    init(socket: SocketService? = nil) {
        if let socket { bind(to: socket) }
    }

    // MARK: - Cliente (escucha del servidor)

    func bind(to socket: SocketService) {
        socket.catalogSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newProducts in
                self?.products = newProducts
            }
            .store(in: &bag)
    }

    // MARK: - Servidor / Utilidades locales

    func replace(with products: [Product]) {
        self.products = products
    }

    func appendLocal(_ p: Product) {
        products.append(p)
    }

    func upsertLocal(_ p: Product) {
        if let i = products.firstIndex(where: { $0.id == p.id }) {
            products[i] = p
        } else {
            products.append(p)
        }
    }

    func removeLocal(at offsets: IndexSet) {
        products.remove(atOffsets: offsets)
    }

    func clear() {
        products.removeAll()
    }

    func updateLocal(_ product: Product) {
        if let idx = products.firstIndex(where: { $0.id == product.id }) {
            products[idx] = product
        }
    }
}

// MARK: - Solo Previews

#if DEBUG
extension ProductsStore {
    static var preview: ProductsStore {
        let store = ProductsStore()
        store.products = [
            Product(id: "p-cafe",    name: "Café2",    imageName: "cafe2",    price: 15, kind: .smoothie),
            Product(id: "p-durazno", name: "Durazno2", imageName: "durazno2", price: 15, kind: .smoothie),
            Product(id: "p-fresa",   name: "Fresa2",   imageName: "fresa2",   price: 15, kind: .smoothie),
            Product(id: "p-kiwi",    name: "Kiwi2",    imageName: "kiwi2",    price: 15, kind: .smoothie),
            Product(id: "p-mango",   name: "Mango2",   imageName: "mango2",   price: 15, kind: .smoothie)
        ]
        return store
    }

    func _setPreviewProducts(_ p: [Product]) { self.products = p }
}
#endif
