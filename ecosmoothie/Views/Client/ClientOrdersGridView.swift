//
//  ClientOrdersGridView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

// ClientOrdersGridView.swift
// ClientOrdersGridView.swift
import SwiftUI

struct ClientOrdersGridView: View {
    @EnvironmentObject var cart: CartStore
    @EnvironmentObject var productsStore: ProductsStore

    @State private var selectedBasePrice: [String: Double] = [:] // product.id -> price
    @State private var selectedProduct: Product?
    @State private var showAssistant = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    private let priceTiers: [Double] = [5, 10, 15, 20, 25]

    var body: some View {
        NavigationStack {
            Group {
                if productsStore.products.isEmpty {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Cargando catálogo…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.almond.opacity(0.12))
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(productsStore.products) { p in
                                ProductCard(
                                    product: p,
                                    selectedPrice: selectedBasePrice[p.id] ?? priceTiers.first!,
                                    onTap: { selectedProduct = p },
                                    onPriceChange: { selectedBasePrice[p.id] = $0 }
                                )
                            }
                        }
                        .padding(12)
                    }
                }
            }
            //.navigationTitle("Tomar pedidos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAssistant = true } label: {
                        Image(systemName: "mic.fill")
                    }
                    .accessibilityLabel("Asistente por voz")
                }
            }
            // Sheet de detalle de producto
            .sheet(item: $selectedProduct) { product in
                let base = selectedBasePrice[product.id] ?? priceTiers.first!
                ProductDetailView(product: product, basePrice: base)
                    .environmentObject(cart)
            }
            // Sheet del asistente por voz (escucha + TTS)
            .sheet(isPresented: $showAssistant) {
                VoiceAssistantView()
            }
        }
    }

    // MARK: - Card
    @ViewBuilder
    private func ProductCard(
        product: Product,
        selectedPrice: Double,
        onTap: @escaping () -> Void,
        onPriceChange: @escaping (Double) -> Void
    ) -> some View {
        VStack(spacing: 8) {
            Image(product.imageName) // cafe2, durazno2, fresa2, kiwi2, mango2
                .resizable()
                .scaledToFill()
                .frame(height: 120)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(product.name)
                .font(.headline)

            Picker("Precio", selection: Binding(
                get: { selectedPrice },
                set: { onPriceChange($0) })
            ) {
                ForEach(priceTiers, id: \.self) { p in
                    Text(String(format: "$%.0f", p)).tag(p)
                }
            }
            .pickerStyle(.segmented)

            Button {
                onTap()
            } label: {
                Text("Elegir ingredientes")
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(.matcha)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.almond.opacity(0.35))
        )
    }
}

#Preview {
    let cart = CartStore()
    let store = ProductsStore()
    // Catálogo de prueba
    store._setPreviewProducts([
        Product(id: "p-cafe",    name: "Café2",    imageName: "cafe2"),
        Product(id: "p-durazno", name: "Durazno2", imageName: "durazno2"),
        Product(id: "p-fresa",   name: "Fresa2",   imageName: "fresa2"),
        Product(id: "p-kiwi",    name: "Kiwi2",    imageName: "kiwi2"),
        Product(id: "p-mango",   name: "Mango2",   imageName: "mango2"),
    ])

    return NavigationStack {
        ClientOrdersGridView()
            .environmentObject(cart)
            .environmentObject(store)
    }
}
