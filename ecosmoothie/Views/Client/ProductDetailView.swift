//
//  ProductDetailView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

// ProductDetailView.swift
import SwiftUI

struct ProductDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var cart: CartStore
    @EnvironmentObject var productsStore: ProductsStore

    let product: Product
    let basePrice: Double

    @State private var ingredients: [IngredientCount] = []
    @State private var showCartPendingAlert = false

    private var extrasTotal: Double {
        ingredients.reduce(0) { $0 + $1.subtotal }
    }
    private var total: Double { basePrice + extrasTotal }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header

                List {
                    ForEach($ingredients) { $ing in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ing.name)
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

                summary
                actionButtons
            }
            .navigationTitle(product.name)
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadIngredients()
        }
        .alert("Carrito pendiente", isPresented: $showCartPendingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Ya hay un pedido en el carrito. Finaliza o vacía el carrito antes de comprar directamente.")
        }
    }

    // MARK: - Cargar ingredientes dinámicos

    private func loadIngredients() {
        let ingredientProducts = productsStore.products.filter { $0.kind == .ingredient }
        ingredients = ingredientProducts.map {
            IngredientCount(
                productId: $0.id,
                name: $0.name,
                pricePerUnit: $0.price,
                count: 0
            )
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 8) {
            if !product.imageName.isEmpty {
                Image(product.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
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
    ProductDetailView(
        product: .init(id: "p-fresa", name: "Fresa", imageName: "fresa2"),
        basePrice: 15
    )
    .environmentObject(CartStore())
    .environmentObject(ProductsStore.preview)
}
