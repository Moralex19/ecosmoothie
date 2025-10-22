//
//  Products.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

// Models.swift
import Foundation

struct Product: Identifiable, Hashable {
    let id: String
    let name: String
    let imageName: String
}

struct IngredientOption: Identifiable, Hashable {
    enum Kind: String { case cereza, frambuesa, picafresa, dulce, gomita }

    let id = UUID()
    let kind: Kind
    let pricePerUnit: Double
    var count: Int = 0

    var subtotal: Double { Double(count) * pricePerUnit }
}

struct CartItem: Identifiable {
    let id = UUID()
    let product: Product
    let basePrice: Double
    let ingredients: [IngredientOption]
    var total: Double {
        basePrice + ingredients.reduce(0) { $0 + $1.subtotal }
    }
}
