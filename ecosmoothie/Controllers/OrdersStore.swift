//
//  OrdersStore.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 22/10/25.
//

// OrdersStore.swift
import Foundation
import Combine

struct ServerOrder: Identifiable, Hashable, Codable {
    enum Status: String, Codable { case pending, paid }

    let id: String
    let items: [CartItem]
    let createdAt: Date
    var status: Status

    var total: Double { items.reduce(0) { $0 + $1.total } }
}

@MainActor
final class OrdersStore: ObservableObject {
    @Published private(set) var orders: [ServerOrder] = []

    var pendingCount: Int { orders.filter { $0.status == .pending }.count }

    private var bag = Set<AnyCancellable>()

    func bind(to socket: SocketService) {
        // Pedidos que llegan desde clientes
        socket.orderIncomingSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.appendIncoming($0) }
            .store(in: &bag)

        // Cambios de estado (p.ej. desde otro servidor)
        socket.orderStatusSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                guard let self,
                      let idx = self.orders.firstIndex(where: { $0.id == update.orderId }) else { return }
                self.orders[idx].status = ServerOrder.Status(rawValue: update.status) ?? .pending
            }
            .store(in: &bag)
    }

    func appendIncoming(_ order: ServerOrder) {
        orders.insert(order, at: 0)
    }

    func markPaid(_ id: String) {
        guard let idx = orders.firstIndex(where: { $0.id == id }) else { return }
        orders[idx].status = .paid
    }

    func remove(_ id: String) {
        orders.removeAll { $0.id == id }
    }

    func markPaid(_ order: ServerOrder) {
        guard let idx = orders.firstIndex(where: { $0.id == order.id }) else { return }
        orders[idx].status = .paid
        // registra la venta
        SalesStore.shared?.logSale(amount: orders[idx].total, date: Date())
        // opcional: avisa por socket
        // socket.sendOrderStatus(orderId: order.id, status: "paid")
    }
}

