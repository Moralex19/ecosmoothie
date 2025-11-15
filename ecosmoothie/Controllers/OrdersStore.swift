//
//  OrdersStore.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 22/10/25.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Model
struct ServerOrder: Identifiable, Hashable, Codable {
    enum Status: String, Codable { case pending, paid }

    let id: String
    let items: [CartItem]
    let createdAt: Date
    var status: Status

    var total: Double {
        items.reduce(0) { $0 + $1.total }
    }
}

// MARK: - Store
@MainActor
final class OrdersStore: ObservableObject {
    @Published private(set) var orders: [ServerOrder] = []

    var pendingCount: Int { orders.filter { $0.status == .pending }.count }

    private var bag = Set<AnyCancellable>()

    // Vinculación con sockets (modo servidor)
    func bind(to socket: SocketService) {
        bag.removeAll()

        // 1) Snapshot inicial al conectarse como servidor
        socket.ordersSnapshotSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.applySnapshot(snapshot)
            }
            .store(in: &bag)

        // 2) Pedidos en tiempo real desde otros clientes
        socket.orderIncomingSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] order in
                self?.appendIncoming(order)
            }
            .store(in: &bag)

        // 3) Cambios de estado (si el backend los envía)
        socket.orderStatusSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                guard
                    let self,
                    let idx = self.orders.firstIndex(where: { $0.id == update.orderId })
                else { return }
                self.orders[idx].status = ServerOrder.Status(rawValue: update.status) ?? .pending
            }
            .store(in: &bag)
    }

    // MARK: - Gestión de pedidos

    private func applySnapshot(_ newOrders: [ServerOrder]) {
        // Ordenamos del más reciente al más antiguo
        self.orders = newOrders.sorted { $0.createdAt > $1.createdAt }
    }

    func appendIncoming(_ order: ServerOrder) {
        print("📥 Nuevo pedido recibido en servidor. Total: \(order.total)")
        orders.insert(order, at: 0) // arriba de la lista
    }

    // MARK: - Operaciones por ID (mantengo tus firmas)
    func markPaid(_ id: String) {
        guard let idx = orders.firstIndex(where: { $0.id == id }) else { return }
        orders[idx].status = .paid
    }

    func remove(_ id: String) {
        orders.removeAll { $0.id == id }
    }

    // MARK: - Operaciones por modelo (las que usan las vistas)
    func delete(_ offsets: IndexSet) {
        orders.remove(atOffsets: offsets)
    }

    func remove(order: ServerOrder) {
        remove(order.id)
    }

    func markPaid(order: ServerOrder) {
        markPaid(order.id)
        // Registrar venta (si usas SalesStore)
        SalesStore.shared?.logSale(amount: order.total, date: Date())
        // Aquí podrías emitir por socket: status paid
        // socket.sendOrderStatus(orderId: order.id, status: "paid")
    }
}

#if DEBUG
extension OrdersStore {
    func _setPreviewOrders(_ o: [ServerOrder]) { self.orders = o }
}
#endif
