//
//  ServerOrderDetailView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 23/10/25.
//

import SwiftUI

struct ServerOrderDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var orders: OrdersStore

    let order: ServerOrder

    @State private var showSaleError = false
    @State private var saleErrorMessage = ""

    var body: some View {
        List {
            // MARK: - Productos
            Section("Productos") {
                ForEach(order.items) { item in   // CartItem es Identifiable
                    VStack(alignment: .leading, spacing: 6) {
                        // Nombre del batido
                        Text(item.product.name)
                            .font(.headline)

                        // Ingredientes (si hay)
                        if !item.ingredients.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(item.ingredients) { ing in
                                    HStack {
                                        Text("\(ing.name) x\( ing.count )")
                                        Spacer()
                                        Text(String(format: "+$%.0f", ing.subtotal))
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Total de la línea
                        HStack {
                            Spacer()
                            Text(String(format: "$%.0f", item.total))
                                .foregroundStyle(Color.matcha)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // MARK: - Resumen
            Section {
                HStack {
                    Text("Total").fontWeight(.semibold)
                    Spacer()
                    Text(order.total, format: .currency(code: "USD"))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.matcha)
                }
            }

            // MARK: - Slide to confirm
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirmar pedido")
                        .font(.headline)

                    Text("Desliza para marcar el pedido como listo y registrar la venta.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    SlideToConfirm(text: "Desliza para confirmar") {
                        confirmOrderAndSaveSale()
                    }
                    .frame(height: 52)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Pedido \(String(order.id.prefix(6)))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    Button(role: .destructive) {
                        orders.remove(order: order)
                        dismiss()
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                    Spacer()
                }
            }
        }
        .alert("Error al guardar venta", isPresented: $showSaleError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saleErrorMessage)
        }
    }

    // MARK: - Lógica

    private func confirmOrderAndSaveSale() {
        // 1. Marcar como pagado en memoria
        orders.markPaid(order: order)

        // 2. Guardar venta en SQLite
        do {
            try OrderDatabase.shared.saveSale(for: order)
        } catch {
            saleErrorMessage = "No se pudo guardar la venta: \(error)"
            showSaleError = true
        }

        // 3. Cerrar detalle
        dismiss()
    }
}

// MARK: - SlideToConfirm (igual que tenías)

struct SlideToConfirm: View {
    let text: String
    let onCompleted: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var didComplete = false

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let knobSize: CGFloat = 44
            let maxDrag = width - knobSize - 4

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 26)
                    .fill(Color(.systemGray6))

                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color.matcha, lineWidth: 2)

                Text(didComplete ? "Pedido listo" : text)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(didComplete ? Color.matcha : .secondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Circle()
                    .fill(Color.matcha)
                    .frame(width: knobSize, height: knobSize)
                    .shadow(radius: 2)
                    .offset(x: dragOffset + 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard !didComplete else { return }
                                let translation = value.translation.width
                                dragOffset = min(max(0, translation), maxDrag)
                            }
                            .onEnded { _ in
                                guard !didComplete else { return }
                                if dragOffset > maxDrag * 0.7 {
                                    dragOffset = maxDrag
                                    didComplete = true
                                    onCompleted()
                                } else {
                                    withAnimation(.spring()) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
            }
        }
    }
}

/*
#Preview {
    NavigationStack {
        ServerOrderDetailView(order: .previewSample)
            .environmentObject(OrdersStore())
    }
}

extension ServerOrder {
    static var previewSample: ServerOrder {
        let ingredients: [IngredientCount] = [
            IngredientCount(kind: .cereza, count: 2),
            IngredientCount(kind: .gomita, count: 1)
        ]

        let item = CartItem(
            product: Product(id: "p-fresa", name: "Fresa", imageName: "fresa2"),
            basePrice: 10,
            ingredients: ingredients
        )

        return ServerOrder(
            id: "ORDER123456",
            items: [item],
            createdAt: Date(),  
            status: .pending
        )
    }
}*/



