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
        List {
            if orders.orders.isEmpty {
                ContentUnavailableView("Sin pedidos aún", systemImage: "tray")
                    .listRowBackground(Color.clear)
            } else {
                ForEach(orders.orders) { o in
                    NavigationLink {
                        ServerOrderDetailView(order: o)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Pedido \(String(o.id.prefix(6)))…")
                                    .font(.headline)
                                Text(o.createdAt, style: .time)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(o.total, format: .currency(code: "USD"))
                                .foregroundStyle(Color.matcha)
                        }
                    }
                }
                .onDelete(perform: orders.delete)   // <- OrdersStore.delete(_: IndexSet)
            }
        }
        .navigationTitle("Pedidos")
    }
}
