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
                            // 👇 Swipe para PAGAR / CANCELAR
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {

                                // CANCELAR (full swipe hacia la izquierda)
                                Button(role: .destructive) {
                                    let id = order.id
                                    DispatchQueue.main.async {
                                        withAnimation {
                                            orders.remove(id)
                                        }
                                    }
                                } label: {
                                    Label("Cancelar", systemImage: "xmark")
                                }

                                // PAGADO (solo si está pendiente)
                                if order.status == .pending {
                                    Button {
                                        let id = order.id
                                        DispatchQueue.main.async {
                                            withAnimation {
                                                orders.markPaid(id)
                                            }
                                        }
                                    } label: {
                                        Label("Pagado", systemImage: "checkmark")
                                    }
                                    .tint(.green)
                                }
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

                // Nombre del cliente
                if let name = order.customerName,
                   !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(name)
                        .font(.subheadline)
                }

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

// MARK: - Preview

struct ServerOrdersListView_Previews: PreviewProvider {
    static var previews: some View {
        // Ingrediente de ejemplo
        let cherry = ServerOrderIngredient(
            productId: "i-cereza",
            name: "Cereza",
            unitPrice: 1,
            count: 1
        )

        // Items de ejemplo
        let item1 = ServerOrderItem(
            productId: "p-fresa",
            name: "Fresa",
            basePrice: 15,
            total: 16,
            ingredients: [cherry]
        )

        let item2 = ServerOrderItem(
            productId: "p-durazno",
            name: "Durazno",
            basePrice: 15,
            total: 15,
            ingredients: []
        )

        // Pedidos de ejemplo
        let order1 = ServerOrder(
            id: "ORDER123456",
            shopId: "tienda-1",
            items: [item1],
            total: 16,
            status: .pending,
            createdAt: Date().addingTimeInterval(-600),
            customerName: "Carlos"
        )

        let order2 = ServerOrder(
            id: "ORDER654321",
            shopId: "tienda-1",
            items: [item1, item2],
            total: 31,
            status: .paid,
            createdAt: Date().addingTimeInterval(-3600),
            customerName: "Ana"
        )

        let store = OrdersStore()
        store._setPreviewOrders([order1, order2])

        return NavigationStack {
            ServerOrdersListView()
                .environmentObject(store)
        }
    }
}
