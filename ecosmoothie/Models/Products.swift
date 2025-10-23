//
//  Products.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

// Products.swift
// Products.swift
import Foundation

// MARK: - Producto
struct Product: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let imageName: String
}

// MARK: - Ingredientes
/// Tipos de ingrediente y su precio por unidad
enum IngredientKind: String, CaseIterable, Hashable, Codable {
    case cereza, frambuesa, picafresa, dulce, gomita

    var price: Double {
        switch self {
        case .cereza:    return 1
        case .frambuesa: return 3
        case .picafresa: return 4
        case .dulce:     return 5
        case .gomita:    return 2
        }
    }

    var displayName: String { rawValue.capitalized }
}

/// Cantidad seleccionada de un ingrediente
struct IngredientCount: Identifiable, Hashable, Codable {
    let id: UUID = UUID()
    var kind: IngredientKind
    var count: Int = 0

    // Computadas ⇒ NO intervienen en Codable
    var pricePerUnit: Double { kind.price }
    var subtotal: Double { Double(count) * pricePerUnit }
}

// MARK: - Ítem de carrito
struct CartItem: Identifiable, Hashable, Codable {
    let id: UUID = UUID()
    let product: Product
    let basePrice: Double
    var ingredients: [IngredientCount]

    // Computada ⇒ NO interviene en Codable
    var total: Double {
        basePrice + ingredients.reduce(0) { $0 + $1.subtotal }
    }
}

// (Opcional) Compatibilidad si en otras vistas usabas IngredientOption
typealias IngredientOption = IngredientCount
