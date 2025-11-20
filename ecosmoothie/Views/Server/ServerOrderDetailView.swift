//
//  ServerOrderDetailView.swift
//  ecosmoothie
//

import SwiftUI

struct ServerOrderDetailView: View {
    let order: ServerOrder

    @EnvironmentObject var ordersStore: OrdersStore
    @Environment(\.dismiss) private var dismiss

    private var statusText: String {
        switch order.status {
        case .pending: return "PENDIENTE"
        case .paid:    return "PAGADO"
        }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pedido \(order.id)")
                        .font(.headline)

                    if let name = order.customerName,
                       !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Cliente: \(name)")
                            .font(.subheadline)
                    }

                    Text(order.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(order.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("Estado: \(statusText)")
                        .font(.subheadline)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section("Productos") {
                ForEach(order.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.name)
                                .font(.headline)
                            Spacer()
                            Text(item.total, format: .currency(code: "USD"))
                                .fontWeight(.semibold)
                        }

                        if !item.ingredients.isEmpty {
                            Text("Extras:")
                                .font(.subheadline)
                            ForEach(item.ingredients) { ing in
                                HStack {
                                    Text("• \(ing.name) x\(ing.count)")
                                    Spacer()
                                    Text(ing.unitPrice, format: .currency(code: "USD"))
                                }
                                .font(.caption)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                HStack {
                    Text("Total")
                    Spacer()
                    Text(order.total, format: .currency(code: "USD"))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.matcha)
                }
            }
        }
        .navigationTitle("Detalle pedido")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if order.status == .pending {
                    Button("Marcar pagado") {
                        ordersStore.markPaid(order: order)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct ServerOrderDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let ing = ServerOrderIngredient(
            productId: "i-cereza",
            name: "Cereza",
            unitPrice: 1,
            count: 1
        )

        let item = ServerOrderItem(
            productId: "p-durazno",
            name: "Durazno",
            basePrice: 15,
            total: 16,
            ingredients: [ing]
        )

        let order = ServerOrder(
            id: "srv-zkpwxi",
            shopId: "tienda-1",
            items: [item],
            total: 16,
            status: .pending,
            createdAt: Date(),
            customerName: "Carlos"
        )

        let store = OrdersStore()
        store._setPreviewOrders([order])

        return NavigationStack {
            ServerOrderDetailView(order: order)
                .environmentObject(store)
        }
    }
}
