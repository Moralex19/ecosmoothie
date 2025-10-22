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

    let product: Product
    let basePrice: Double

    @State private var ingredients: [IngredientOption] = [
        .init(kind: .cereza,    pricePerUnit: 1),
        .init(kind: .frambuesa, pricePerUnit: 3),
        .init(kind: .picafresa, pricePerUnit: 4),
        .init(kind: .dulce,     pricePerUnit: 5),
        .init(kind: .gomita,    pricePerUnit: 2),
    ]

    @State private var showCartPendingAlert = false
    @State private var showAddedToast = false

    private func title(for kind: IngredientOption.Kind) -> String {
        switch kind {
        case .cereza: return "Cereza"
        case .frambuesa: return "Frambuesa"
        case .picafresa: return "Picafresa"
        case .dulce: return "Dulce"
        case .gomita: return "Gomita"
        }
    }

    var extrasTotal: Double {
        ingredients.reduce(0) { $0 + $1.subtotal }
    }

    var total: Double { basePrice + extrasTotal }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header

                List {
                    ForEach($ingredients) { $ing in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(title(for: ing.kind))
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
                        Text(String(format: "$%.0f", total)).fontWeight(.semibold)
                            .foregroundStyle(Color.matcha)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.almond.opacity(0.35)))
                .padding(.horizontal)

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

    private var header: some View {
        VStack(spacing: 8) {
            Image(product.imageName)
                .resizable().scaledToFit()
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text("Selecciona ingredientes")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var actionButtons: some View {
        HStack {
            Button {
                // Comprar directo: si carrito tiene cosas, alerta de “carrito pendiente”
                if cart.count > 0 {
                    showCartPendingAlert = true
                    return
                }
                let item = CartItem(product: product, basePrice: basePrice, ingredients: ingredients)
                cart.add(item)
                // Aquí podrías navegar a “Checkout”; por ahora regresamos
                dismiss()
            } label: {
                Text("Comprar")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.bordered)

            Button {
                let item = CartItem(product: product, basePrice: basePrice, ingredients: ingredients)
                cart.add(item)
                // Regresar al menú
                dismiss()
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
}

#Preview {
    ProductDetailView(product: .init(id: "p-fresa", name: "Fresa", imageName: "fresa"),
                      basePrice: 10)
    .environmentObject(CartStore())
}

