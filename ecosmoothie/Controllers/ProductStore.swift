//
//  ProductStore.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

// ProductsStore.swift
// ProductsStore.swift
import Foundation
import Combine

/// Catálogo vivo del cliente. Se alimenta por sockets (catalog.updated).
final class ProductsStore: ObservableObject {
    /// Productos visibles en el cliente (grid de “Tomar pedidos”).
    @Published private(set) var products: [Product] = [
        // Base local por si el socket tarda
        Product(id: "p-cafe",    name: "Café",    imageName: "cafe2"),
        Product(id: "p-durazno", name: "Durazno", imageName: "durazno2"),
        Product(id: "p-fresa",   name: "Fresa",   imageName: "fresa2"),
        Product(id: "p-kiwi",    name: "Kiwi",    imageName: "kiwi2"),
        Product(id: "p-mango",   name: "Mango",   imageName: "mango2"),
    ]

    private var bag = Set<AnyCancellable>()

    init(socket: SocketService? = nil) {
        if let socket { bind(to: socket) }
    }

    /// Vincula el store a los eventos del socket. Cuando el servidor emite `catalog.updated`
    /// reemplazamos el catálogo (o aquí puedes hacer un diff si lo prefieres).
    func bind(to socket: SocketService) {
        socket.catalogSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newProducts in
                self?.products = newProducts
            }
            .store(in: &bag)
    }

    // MARK: - Helpers internos

    /// Permite actualizar el catálogo desde otras capas (p. ej., primer fetch REST).
    func replace(with products: [Product]) {
        self.products = products
    }
}

// MARK: - Solo para Previews
#if DEBUG
extension ProductsStore {
    /// Para usar productos mock en `#Preview` aunque `products` sea `private(set)`.
    func _setPreviewProducts(_ p: [Product]) { self.products = p }
}
#endif
