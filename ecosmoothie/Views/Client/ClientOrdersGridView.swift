//
//  ClientOrdersGridView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

import SwiftUI

struct ClientOrdersGridView: View {
    @EnvironmentObject var cart: CartStore
    @EnvironmentObject var productsStore: ProductsStore

    @State private var selectedProduct: Product?
    @State private var showAssistant = false

    // Para detectar nuevos productos
    @State private var previousProductIDs: Set<String> = []
    @State private var showNewProductsBanner = false
    @State private var newProductsMessage = ""

    @Environment(\.horizontalSizeClass) private var hSizeClass

    // Columnas responsivas: 2 en iPhone, 3 en iPad
    private var columns: [GridItem] {
        if hSizeClass == .compact {
            return [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ]
        } else {
            return [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ]
        }
    }

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
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(productsStore.products) { p in
                                ProductCard(
                                    product: p,
                                    onTap: { selectedProduct = p }
                                )
                            }
                        }
                        .padding(16)
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
                let base = product.price > 0 ? product.price : 10
                ProductDetailView(product: product, basePrice: base)
                    .environmentObject(cart)
            }
            // Sheet del asistente por voz (escucha + TTS)
            .sheet(isPresented: $showAssistant) {
                VoiceAssistantView()
            }
            // Banner cuando llegan nuevos productos
            .overlay(alignment: .top) {
                if showNewProductsBanner {
                    NewProductsBanner(text: newProductsMessage)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            // Guardamos el estado inicial de los productos
            previousProductIDs = Set(productsStore.products.map { $0.id })
        }
        .onChange(of: productsStore.products) { _ in
            handleProductsChange()
        }
    }

    // MARK: - Card
    @ViewBuilder
    private func ProductCard(
        product: Product,
        onTap: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 8) {
            productImage(for: product)
                .aspectRatio(1, contentMode: .fill)   // cuadrada, no se deforma
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(spacing: 4) {
                Text(product.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(String(format: "$ %.2f", product.price))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.matcha)
            }
            .frame(maxWidth: .infinity)

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

    // Imagen de producto: primero intenta desde disco (galería), luego asset
    @ViewBuilder
    private func productImage(for product: Product) -> some View {
        if let uiImage = loadImageFromDisk(named: product.imageName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            Image(product.imageName)
                .resizable()
                .scaledToFill()
        }
    }

    // MARK: - Manejo de nuevos productos

    private func handleProductsChange() {
        let currentIDs = Set(productsStore.products.map { $0.id })
        let added = currentIDs.subtracting(previousProductIDs)

        guard !added.isEmpty else {
            previousProductIDs = currentIDs
            return
        }

        let count = added.count
        newProductsMessage = count == 1
            ? "Se agregó 1 nuevo producto"
            : "Se agregaron \(count) nuevos productos"

        previousProductIDs = currentIDs

        withAnimation {
            showNewProductsBanner = true
        }

        // Ocultar banner después de unos segundos
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showNewProductsBanner = false
            }
        }
    }
}

// MARK: - Banner de nuevos productos

private struct NewProductsBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(radius: 3)
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
