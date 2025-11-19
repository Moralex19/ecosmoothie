//
//  CartStore.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

import SwiftUI
import Combine

@MainActor
final class CartStore: ObservableObject {
    @Published private(set) var items: [CartItem] = []
    
    struct Purchase: Identifiable, Hashable, Codable {
        let id: UUID = UUID()
        let date: Date
        let items: [CartItem]
        let total: Double
        var status: String = "pending"
    }
    
    @Published private(set) var history: [Purchase] = []
    
    // MARK: - Métricas
    
    var count: Int  { items.count }
    var total: Double { items.reduce(0) { $0 + $1.total } }
    
    // MARK: - Operaciones principales
    
    /// Añadir un CartItem ya creado
    func add(_ item: CartItem) {
        precondition(Thread.isMainThread, "CartStore.add debe ejecutarse en MainActor")
        items.append(item)
        print("🛒 add -> items:", items.count, " total:", total)
    }
    
    /// Opcional: añadir un Product con precio base fijo (15)
    func add(product: Product) {
        let item = CartItem(
            product: product,
            basePrice: 15,        // 👈 precio base fijo
            ingredients: []
        )
        add(item)
    }
    
    func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
    
    func clear() {
        items.removeAll()
    }
    
    // MARK: - Historial
    
    func logCurrentCartAsPurchase() {
        guard !items.isEmpty else { return }
        let p = Purchase(date: Date(), items: items, total: total)
        history.insert(p, at: 0)
    }
    
    func clearHistory() {
        history.removeAll()
    }
}

#if DEBUG
extension CartStore {
    /// Solo para usar en #Preview: permite inyectar ítems de carrito
    func _setPreviewItems(_ items: [CartItem]) {
        self.items = items
    }
}
#endif

