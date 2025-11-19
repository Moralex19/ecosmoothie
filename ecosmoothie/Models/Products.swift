//
//  Products.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

import Foundation

// MARK: - Producto

struct Product: Identifiable, Hashable, Codable {
    enum Kind: String, Codable, CaseIterable {
        case smoothie    // batido principal
        case ingredient  // ingrediente extra (se edita solo en servidor)
    }

    let id: String
    var name: String
    var imageName: String
    var price: Double
    var kind: Kind

    /// Inicializador principal (para código nuevo y para SQLite/JSON)
    init(
        id: String,
        name: String,
        imageName: String,
        price: Double,
        kind: Kind
    ) {
        self.id = id
        self.name = name
        self.imageName = imageName
        self.price = price
        self.kind = kind
    }

    /// Inicializador de compatibilidad:
    /// permite seguir usando `Product(id:name:imageName:)`
    /// en previews o código viejo. Asigna precio 0 y tipo .smoothie.
    init(id: String, name: String, imageName: String) {
        self.init(
            id: id,
            name: name,
            imageName: imageName,
            price: 0,
            kind: .smoothie
        )
    }
}

// MARK: - Ingrediente en el carrito
/// Representa la selección de un ingrediente (que en catálogo es un `Product.kind == .ingredient`)
struct IngredientCount: Identifiable, Hashable, Codable {
    let id: UUID
    /// id del Product que representa este ingrediente
    let productId: String
    var name: String
    var pricePerUnit: Double
    var count: Int

    var subtotal: Double { Double(count) * pricePerUnit }

    init(
        id: UUID = UUID(),
        productId: String,
        name: String,
        pricePerUnit: Double,
        count: Int = 0
    ) {
        self.id = id
        self.productId = productId
        self.name = name
        self.pricePerUnit = pricePerUnit
        self.count = count
    }
}

// MARK: - Ítem de carrito

struct CartItem: Identifiable, Hashable, Codable {
    let id: UUID
    let product: Product          // smoothie elegido
    let basePrice: Double         // precio base del smoothie
    var ingredients: [IngredientCount]

    /// Total = base + extras
    var total: Double {
        basePrice + ingredients.reduce(0) { $0 + $1.subtotal }
    }

    init(
        id: UUID = UUID(),
        product: Product,
        basePrice: Double,
        ingredients: [IngredientCount]
    ) {
        self.id = id
        self.product = product
        self.basePrice = basePrice
        self.ingredients = ingredients
    }
}

// Compatibilidad si antes usabas IngredientOption
typealias IngredientOption = IngredientCount
