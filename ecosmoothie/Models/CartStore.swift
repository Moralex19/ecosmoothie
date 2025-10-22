//
//  CartStore.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

// CartStore.swift
import Foundation
import Combine
import SwiftUI

final class CartStore: ObservableObject {
    @Published private(set) var items: [CartItem] = []

    var count: Int { items.count }
    var total: Double { items.reduce(0) { $0 + $1.total } }

    func add(_ item: CartItem) {
        items.append(item)
    }

    func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    func clear() { items.removeAll() }
}


