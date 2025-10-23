//
//  ServerOrdersView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 22/10/25.
//

// ServerOrdersView.swift
import SwiftUI

struct ServerOrdersListView: View {
    @EnvironmentObject var orders: OrdersStore

    var body: some View {
        Group {
            if orders.orders.isEmpty {
                ContentUnavailableView("Sin pedidos aún", systemImage: "tray")
            } else {
                List {
                    ForEach(orders.orders) { o in
                        NavigationLink(value: o) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Pedido \(o.id.prefix(6))…")
                                        .font(.headline)
                                    Text(o.createdAt, style: .time)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(o.total, format: .currency(code: "USD"))
                                    .foregroundStyle(.matcha)
                            }
                        }
                    }
                    .onDelete { idx in orders.delete(at: idx) }
                }
                .navigationDestination(for: ServerOrder.self) { order in
                    ServerOrderDetailView(order: order)
                }
            }
        }
        .navigationTitle("Pedidos")
    }
}

struct ServerOrderDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var orders: OrdersStore

    let order: ServerOrder

    var body: some View {
        List {
            Section("Productos") {
                ForEach(order.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.product.name).font(.headline)
                        if !item.ingredients.isEmpty {
                            Text(item.ingredients.map { "\($0.kind.rawValue) x\($0.count)" }.joined(separator: ", "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        HStack {
                            Spacer()
                            Text(item.total, format: .currency(code: "USD"))
                                .foregroundStyle(.matcha).fontWeight(.semibold)
                        }
                    }
                }
            }
            Section {
                HStack {
                    Text("Total").fontWeight(.semibold)
                    Spacer()
                    Text(order.total, format: .currency(code: "USD"))
                        .fontWeight(.semibold).foregroundStyle(.matcha)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button(role: .destructive) {
                    orders.remove(order)
                    dismiss()
                } label: { Label("Eliminar", systemImage: "trash") }

                Spacer()

                Button {
                    orders.markPaid(order)
                    dismiss()
                } label: { Label("Cobrar", systemImage: "creditcard") }
                .buttonStyle(.borderedProminent)
                .tint(.matcha)
            }
        }
        .navigationTitle("Pedido \(order.id.prefix(6))…")
    }
}

