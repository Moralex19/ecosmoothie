//
//  ProductDetailView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

// ProductDetailView.swift
// ProductDetailView.swift
import SwiftUI

struct ProductDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var cart: CartStore

    let product: Product
    let basePrice: Double

    // Lista editable de ingredientes (tipo + contador)
    @State private var ingredients: [IngredientCount] = [
        .init(kind: .cereza,    count: 0),
        .init(kind: .frambuesa, count: 0),
        .init(kind: .picafresa, count: 0),
        .init(kind: .dulce,     count: 0),
        .init(kind: .gomita,    count: 0)
    ]

    @State private var showCartPendingAlert = false

    // Totales
    private var extrasTotal: Double {
        ingredients.reduce(0) { $0 + $1.subtotal }
    }
    private var total: Double { basePrice + extrasTotal }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header

                // Lista de ingredientes con Stepper por cada uno
                List {
                    ForEach($ingredients, id: \.kind) { $ing in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ing.kind.displayName)
                                Text(String(format: "+ $%.0f c/u", ing.pricePerUnit))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Stepper(value: $ing.count, in: 0...99) {
                                Text("\(ing.count)")
                                    .frame(width: 28)
                            }
                            .labelsHidden()
                        }
                        .listRowBackground(Color.almond.opacity(0.25))
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.almond.opacity(0.12))

                // Resumen
                summary

                // Acciones
                actionButtons
            }
            .navigationTitle(product.name)
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Carrito pendiente", isPresented: $showCartPendingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Ya hay un pedido en el carrito. Finaliza o vacía el carrito antes de comprar directamente.")
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 8) {
            Image(product.imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text("Selecciona ingredientes")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var summary: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Base")
                Spacer()
                Text(String(format: "$%.0f", basePrice))
            }
            HStack {
                Text("Extras")
                Spacer()
                Text(String(format: "$%.0f", extrasTotal))
            }
            Divider()
            HStack {
                Text("Total").fontWeight(.semibold)
                Spacer()
                Text(String(format: "$%.0f", total))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.matcha)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.almond.opacity(0.35)))
        .padding(.horizontal)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Comprar directo
            Button {
                if cart.count > 0 {
                    showCartPendingAlert = true
                    return
                }
                addToCartAndDismiss()
            } label: {
                Text("Comprar")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.bordered)

            // Agregar al carrito
            Button {
                addToCartAndDismiss()
            } label: {
                Text("Agregar al carrito")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(.matcha)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    // MARK: - Helpers

    private func addToCartAndDismiss() {
        let selected = ingredients.filter { $0.count > 0 }
        let item = CartItem(product: product, basePrice: basePrice, ingredients: selected)
        Task { @MainActor in
            cart.add(item)
            dismiss()
        }
    }

}

#Preview {
    ProductDetailView(product: .init(id: "p-fresa", name: "Fresa", imageName: "fresa2"),
                      basePrice: 10)
        .environmentObject(CartStore())
}
