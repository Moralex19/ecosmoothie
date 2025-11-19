//
//  ClientCardView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

import SwiftUI
import Combine
import SQLite3

struct ClientCartView: View {
    @EnvironmentObject var cart: CartStore
    @EnvironmentObject var socket: SocketService   // para enviar el pedido por sockets

    @StateObject private var holder = Holder()
    @State private var showEmptyAlert = false
    @State private var orderStatus: String?

    // 🔹 Estados para flujo de pago
    @State private var showPaymentOptions = false
    @State private var showPaymentConfirm = false
    @State private var showThankYou = false        // 🔹 Gracias solo después de confirmar

    private enum PaymentMethod {
        case transfer
        case cash
    }

    @State private var selectedPaymentMethod: PaymentMethod?

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
        //.navigationTitle("Carrito")
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
                        if cart.items.isEmpty {
                            showEmptyAlert = true
                            return
                        }

                        // Mostrar opciones de método de pago
                        showPaymentOptions = true
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
            // 🔴 IMPORTANTE: limpiar sinks antes de volver a suscribirse
            holder.bag.removeAll()

            // Escucha cambios de estado desde el servidor (una sola suscripción)
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
        // 🔴 IMPORTANTE: limpiar al salir para que no se acumulen suscripciones
        .onDisappear {
            holder.bag.removeAll()
        }

        // ALERTA: Carrito vacío
        .alert("Carrito vacío", isPresented: $showEmptyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Agrega productos antes de pagar.")
        }

        // DIALOGO: Seleccionar método de pago
        .confirmationDialog(
            "Selecciona el método de pago",
            isPresented: $showPaymentOptions
        ) {
            Button("Transferencia bancaria") {
                selectedPaymentMethod = .transfer
                showPaymentConfirm = true
            }
            Button("Efectivo") {
                selectedPaymentMethod = .cash
                showPaymentConfirm = true
            }
            Button("Cancelar", role: .cancel) {
                // Usuario decidió no pagar al final
            }
        } message: {
            Text("Elige cómo deseas realizar tu pago.")
        }

        // ALERTA: Confirmación de pago (con opción de cancelar)
        .alert(
            paymentTitle,
            isPresented: $showPaymentConfirm
        ) {
            Button("Cancelar", role: .cancel) {
                // No se paga ni se envía nada
            }
            Button("Confirmar pago") {
                // Ejecutar el flujo real de pago / envío
                processPayment()
                // 🔹 Mostrar mensaje de gracias SOLO después de confirmar
                showThankYou = true
            }
        } message: {
            Text(paymentMessage)
        }

        // ALERTA: Gracias por la compra (después de confirmar)
        .alert("¡Gracias por tu compra!", isPresented: $showThankYou) {
            Button("OK") {}
        } message: {
            Text("Tu pago se ha realizado correctamente.")
        }
    }

    // MARK: - Holder para subscripciones y puente de checkout
    final class Holder: ObservableObject {
        var bag = Set<AnyCancellable>()
        @Published var status: String?
        var bridge: ClientCartCheckoutBridge?
    }

    // MARK: - Helpers de pago

    private var paymentTitle: String {
        switch selectedPaymentMethod {
        case .transfer:
            return "Pago por transferencia"
        case .cash:
            return "Pago en efectivo"
        case .none:
            return "Pago"
        }
    }

    private var paymentMessage: String {
        let totalString = String(format: "$ %.2f", cart.total)

        switch selectedPaymentMethod {
        case .transfer:
            return """
Pagarás por transferencia bancaria.

Usa como ejemplo esta tarjeta:
1234 1234 1234 1234

Total a pagar: \(totalString)
"""
        case .cash:
            return """
Pagarás en efectivo.

Total a pagar: \(totalString)
"""
        case .none:
            return ""
        }
    }

    private func processPayment() {
        // 1. Enviar pedido por sockets
        holder.bridge?.checkout(cartItems: cart.items)

        // 2. Guardar detalle del pedido en SQLite
        do {
            try OrderDatabase.shared.saveOrder(items: cart.items, total: cart.total)
            print("✅ Pedido guardado en SQLite")
        } catch {
            print("❌ Error al guardar pedido en SQLite: \(error)")
        }

        // 3. Limpiar carrito una vez pagado
        cart.clear()

        // 4. Resetear selección de método de pago por si acaso
        selectedPaymentMethod = nil
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
/*
#Preview {
    let cart = CartStore()

    // Item de carrito de prueba SIN ingredientes
    let item = CartItem(
        product: Product(
            id: "p-fresa",
            name: "Fresa",
            imageName: "fresa2",
            price: 15,
            kind: .smoothie
        ),
        basePrice: 10,
        ingredients: []        
    )
    cart._setPreviewItems([item])

    let socket = SocketService()

    NavigationStack {          // 👈 OJO: SIN `return`
        ClientCartView()
            .environmentObject(cart)
            .environmentObject(socket)
    }
}
*/
