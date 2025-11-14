//
//  ServerOrdersListView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 23/10/25.
//

import SwiftUI

struct ServerOrdersListView: View {
    @EnvironmentObject var orders: OrdersStore

    var body: some View {
        NavigationStack {
            Group {
                if orders.orders.isEmpty {
                    // ESTADO VACÍO
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.system(size: 52))
                            .foregroundStyle(.secondary)
                        Text("Pedidos vacíos")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.almond.opacity(0.15))
                } else {
                    // LISTA DE PEDIDOS
                    List {
                        ForEach(orders.orders) { order in
                            NavigationLink {
                                ServerOrderDetailView(order: order)
                            } label: {
                                OrderRow(order: order)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.almond.opacity(0.15))
                }
            }
            //.navigationTitle("Pedidos")
        }
    }
}

// MARK: - Fila de pedido

private struct OrderRow: View {
    let order: ServerOrder

    private var statusColor: Color {
        switch order.status {
        case .pending: return .yellow.opacity(0.4)
        case .paid:    return .green.opacity(0.4)
        }
    }

    private var statusText: String {
        switch order.status {
        case .pending: return "PENDIENTE"
        case .paid:    return "PAGADO"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pedido \(order.id.prefix(6))")
                    .font(.headline)

                Text(order.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(order.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(order.total, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.matcha)

                Text(statusText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(statusColor))
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    // Ingredientes de prueba
    let ings: [IngredientCount] = [
        IngredientCount(kind: .cereza, count: 2),
        IngredientCount(kind: .gomita, count: 1)
    ]

    // Producto + item de carrito de prueba
    let product = Product(id: "p-fresa", name: "Fresa", imageName: "fresa2")
    let cartItem = CartItem(product: product, basePrice: 10, ingredients: ings)

    // Pedidos de prueba
    let order1 = ServerOrder(
        id: "ORDER123456",
        items: [cartItem],
        createdAt: Date().addingTimeInterval(-600),
        status: .pending
    )

    let order2 = ServerOrder(
        id: "ORDER654321",
        items: [cartItem, cartItem],
        createdAt: Date().addingTimeInterval(-3600),
        status: .paid
    )

    let store = OrdersStore()
    store._setPreviewOrders([order1, order2])

    return NavigationStack {
        ServerOrdersListView()
            .environmentObject(store)
    }
}
