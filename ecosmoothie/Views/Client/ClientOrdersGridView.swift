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

    @State private var previousProductIDs: Set<String> = []
    @State private var showNewProductsBanner = false
    @State private var newProductsMessage = ""

    @Environment(\.horizontalSizeClass) private var hSizeClass

    // Solo sabores base
    private var smoothies: [Product] {
        productsStore.products.filter { $0.kind == .smoothie }
    }

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
                if smoothies.isEmpty {
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
                            ForEach(smoothies) { p in
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAssistant = true } label: {
                        Image(systemName: "mic.fill")
                    }
                    .accessibilityLabel("Asistente por voz")
                }
            }
            .sheet(item: $selectedProduct) { product in
                let base = product.price > 0 ? product.price : 15
                ProductDetailView(product: product, basePrice: base)
                    .environmentObject(cart)
            }
            .sheet(isPresented: $showAssistant) {
                VoiceAssistantView()
            }
            .overlay(alignment: .top) {
                if showNewProductsBanner {
                    NewProductsBanner(text: newProductsMessage)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .onAppear {
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
        let displayPrice = product.price > 0 ? product.price : 15.0

        VStack(spacing: 8) {
            productImage(for: product)
                .aspectRatio(1, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(spacing: 4) {
                Text(product.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(String(format: "$ %.2f", displayPrice))
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

    @ViewBuilder
    private func productImage(for product: Product) -> some View {
        if let uiImage = loadImageFromDisk(named: product.imageName), !product.imageName.isEmpty {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if !product.imageName.isEmpty {
            Image(product.imageName)
                .resizable()
                .scaledToFill()
        } else {
            Color.almond.opacity(0.4) // placeholder para ingredientes sin foto
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showNewProductsBanner = false
            }
        }
    }
}

// MARK: - Banner

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
    NavigationStack {
        ClientOrdersGridView()
            .environmentObject(CartStore())
            .environmentObject(ProductsStore.preview)
    }
}
