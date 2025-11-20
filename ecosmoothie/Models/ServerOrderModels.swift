//
//  ServerOrderModels.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 20/11/25.
//

import Foundation

struct ServerOrder: Identifiable, Hashable, Codable {
    enum Status: String, Codable {
        case pending
        case paid
        // Si el backend añade más: case preparing, ready, etc
    }

    let id: String
    let shopId: String
    let items: [ServerOrderItem]
    let total: Double
    var status: Status
    let createdAt: Date
    let customerName: String?   // el backend puede mandarlo o no
}

// Hacemos los items Identifiable para poder usarlos en ForEach sin problemas
struct ServerOrderItem: Identifiable, Hashable, Codable {
    var id: String { productId }   // usamos el productId como id

    let productId: String
    let name: String
    let basePrice: Double
    let total: Double
    let ingredients: [ServerOrderIngredient]
}

struct ServerOrderIngredient: Identifiable, Hashable, Codable {
    var id: String { productId }   // también productId como id

    let productId: String
    let name: String
    let unitPrice: Double
    let count: Int
}
