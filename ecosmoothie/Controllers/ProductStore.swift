//
//  ProductStore.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

// ProductsStore.swift
import Foundation
import Combine
import SwiftUI

/// Catálogo compartido. En cliente se alimenta por sockets (`catalog.updated`);
/// en servidor puedes mutarlo localmente (append/remove) y luego emitir por socket.
@MainActor
final class ProductsStore: ObservableObject {
    @Published private(set) var products: [Product] = [
        // Base local por si el socket tarda
        .init(id: "p-cafe",    name: "Café",    imageName: "cafe2"),
        .init(id: "p-durazno", name: "Durazno", imageName: "durazno2"),
        .init(id: "p-fresa",   name: "Fresa",   imageName: "fresa2"),
        .init(id: "p-kiwi",    name: "Kiwi",    imageName: "kiwi2"),
        .init(id: "p-mango",   name: "Mango",   imageName: "mango2"),
    ]

    private var bag = Set<AnyCancellable>()

    // Puedes inyectar el socket al crear; si no, llama bind(to:) después.
    init(socket: SocketService? = nil) {
        if let socket { bind(to: socket) }
    }

    // MARK: - Cliente (escucha del servidor)

    /// Vincula el store a los eventos del socket. Cuando el servidor emite
    /// `catalog.updated` reemplazamos el catálogo (puedes hacer diff si quieres).
    func bind(to socket: SocketService) {
        socket.catalogSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newProducts in
                self?.products = newProducts
            }
            .store(in: &bag)
    }

    // MARK: - Servidor / Utilidades locales

    /// Reemplaza todo el catálogo (p. ej. primer fetch REST/SQLite).
    func replace(with products: [Product]) {
        self.products = products
    }

    /// Inserta un producto localmente (modo servidor).
    func appendLocal(_ p: Product) {
        products.append(p)
    }

    /// Inserta o actualiza por id.
    func upsertLocal(_ p: Product) {
        if let i = products.firstIndex(where: { $0.id == p.id }) {
            products[i] = p
        } else {
            products.append(p)
        }
    }

    /// Elimina usando IndexSet (compat. con List.onDelete).
    func removeLocal(at offsets: IndexSet) {
        products.remove(atOffsets: offsets)
    }

    /// Vacía el catálogo.
    func clear() {
        products.removeAll()
    }
}

extension ProductsStore {
    func updateLocal(_ product: Product) {
        if let idx = products.firstIndex(where: { $0.id == product.id }) {
            products[idx] = product
        }
    }
}

// MARK: - Solo Previews
#if DEBUG
extension ProductsStore {
    /// Permite setear productos mock en `#Preview` aunque `products` sea `private(set)`.
    func _setPreviewProducts(_ p: [Product]) { self.products = p }
}
#endif
