//
//  CartStore.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

// CartStore.swift
import SwiftUI
import Combine   // <- necesario para ObservableObject en algunos setups

// CartStore.swift
import SwiftUI

@MainActor
final class CartStore: ObservableObject {
    @Published private(set) var items: [CartItem] = []

    var count: Int  { items.count }
    var total: Double { items.reduce(0) { $0 + $1.total } }

    func add(_ item: CartItem) {
        // Si llegara a llamarse fuera del main, esto crashea con mensaje claro:
        precondition(Thread.isMainThread, "CartStore.add debe ejecutarse en MainActor")
        items.append(item)
        print("🛒 add -> items:", items.count, " total:", total)
    }

    func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    func clear() {
        items.removeAll()
    }
}







