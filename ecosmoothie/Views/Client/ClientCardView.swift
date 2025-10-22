//
//  ClientCardView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

// ClientCartView.swift
// ClientCartView.swift
import SwiftUI
import Combine

struct ClientCartView: View {
    @EnvironmentObject var cart: CartStore
    @EnvironmentObject var socket: SocketService   // para enviar el pedido por sockets

    @StateObject private var holder = Holder()
    @State private var showEmptyAlert = false
    @State private var orderStatus: String?

    var body: some View {
        Group {
            if cart.items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "cart")
                        .font(.system(size: 52))
                        .foregroundStyle(.secondary)
                    Text("Tu carrito está vacío")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.almond.opacity(0.15))
            } else {
                List {
                    ForEach(cart.items) { item in
                        CartRow(item: item)
                            .listRowBackground(Color.almond.opacity(0.35))
                    }
                    .onDelete(perform: cart.remove)

                    Section {
                        HStack {
                            Text("Total del carrito").fontWeight(.semibold)
                            Spacer()
                            Text(String(format: "$ %.2f", cart.total))
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.matcha)
                        }

                        if let status = orderStatus {
                            HStack {
                                Text("Estado del pedido")
                                Spacer()
                                Text(status.uppercased())
                                    .font(.caption).fontWeight(.semibold)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Capsule().fill(Color.pistache))
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.almond.opacity(0.15))
            }
        }
        .navigationTitle("Carrito")
        .toolbar {
            // Botón Editar + Vaciar
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
                if !cart.items.isEmpty {
                    Button("Vaciar") { cart.clear() }
                }
            }

            // BOTÓN DE PAGO — en la barra inferior (no tapa la TabBar)
            ToolbarItem(placement: .bottomBar) {
                if !cart.items.isEmpty {
                    Button {
                        if cart.items.isEmpty { showEmptyAlert = true; return }
                        holder.bridge?.checkout(cartItems: cart.items)
                        // cart.clear()  // opcional: limpiar al enviar o espera ACK del server
                    } label: {
                        HStack {
                            Image(systemName: "creditcard")
                            Text("Pagar y enviar pedido").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.matcha)
                }
            }
        }
        .onAppear {
            if holder.bridge == nil {
                holder.bridge = ClientCartCheckoutBridge(socket: socket)
            }
            // Escucha cambios de estado desde el servidor
            socket.orderStatusSubject
                .receive(on: DispatchQueue.main)
                .sink { [weak holder] update in
                    holder?.status = update.status
                }
                .store(in: &holder.bag)
        }
        .onChange(of: holder.status) { _, new in
            orderStatus = new
        }
        .alert("Carrito vacío", isPresented: $showEmptyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Agrega productos antes de pagar.")
        }
    }

    // MARK: - Holder para subscripciones y puente de checkout
    final class Holder: ObservableObject {
        var bag = Set<AnyCancellable>()
        @Published var status: String?
        var bridge: ClientCartCheckoutBridge?
    }
}

// MARK: - Fila del carrito
private struct CartRow: View {
    let item: CartItem

    private var extrasCount: Int {
        item.ingredients.reduce(0) { $0 + $1.count }
    }
    private var extrasCost: Double {
        item.ingredients.reduce(0) { $0 + $1.subtotal }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(item.product.imageName)
                .resizable().scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.product.name).font(.headline)
                HStack {
                    Text(String(format: "Base: $%.2f", item.basePrice))
                    if extrasCount > 0 {
                        Text(String(format: " • Extras: %d (+$%.2f)", extrasCount, extrasCost))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(String(format: "$%.2f", item.total))
                .fontWeight(.semibold)
                .foregroundStyle(Color.matcha)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    let cart = CartStore()
    // ejemplo rápido de item
    cart.add(CartItem(
        product: .init(id: "p-fresa", name: "Fresa", imageName: "fresa2"),
        basePrice: 10,
        ingredients: [
            .init(kind: .cereza,   pricePerUnit: 1, count: 2),
            .init(kind: .gomita,   pricePerUnit: 2, count: 1),
        ]
    ))

    let socket = SocketService()

    return NavigationStack {
        ClientCartView()
            .environmentObject(cart)
            .environmentObject(socket)
    }
}


