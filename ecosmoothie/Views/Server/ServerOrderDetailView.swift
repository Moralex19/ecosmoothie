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

    var body: some View {
        List {
            Section("Productos") {
                ForEach(order.items, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.product.name)
                            .font(.headline)

                        if !item.ingredients.isEmpty {
                            Text(
                                item.ingredients
                                    .map { "\($0.kind.rawValue) x\($0.count)" }
                                    .joined(separator: ", ")
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        HStack {
                            Spacer()
                            Text(item.total, format: .currency(code: "USD"))
                                .foregroundStyle(Color.matcha)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Section {
                HStack {
                    Text("Total").fontWeight(.semibold)
                    Spacer()
                    Text(order.total, format: .currency(code: "USD"))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.matcha)
                }
            }
        }
        .navigationTitle("Pedido \(String(order.id.prefix(6)))")
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button(role: .destructive) {
                    orders.remove(order: order)
                    dismiss()
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }

                Spacer()

                Button {
                    orders.markPaid(order: order)
                    dismiss()
                } label: {
                    Label("Cobrar", systemImage: "creditcard")
                }
                .buttonStyle(.borderedProminent)
                .tint(.matcha)
            }
        }
    }
}
