//
//  SocketService.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

// SocketService.swift
import Foundation
import Combine

enum SocketRole: String { case client, server }

enum SocketEvent: String {
    case authOK           = "auth.ok"
    case catalogUpdated   = "catalog.updated"
    case orderCreatedAck  = "order.created_ack"
    case orderStatus      = "order.status_changed"
    case orderCreate      = "order.create"          // NEW: lo que envía el cliente
}

final class SocketService: ObservableObject {
    @Published var isConnected = false
    @Published var lastEvent: String = ""

    let catalogSubject = PassthroughSubject<[Product], Never>()
    let orderStatusSubject = PassthroughSubject<(orderId: String, status: String), Never>()
    let orderIncomingSubject = PassthroughSubject<ServerOrder, Never>()   // NEW

    private var task: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private let url: URL

    private var jwt: String = ""
    var shopId: String = ""                   // hazlo internal para sendCatalog
    private var role: SocketRole = .client

    static let WS_URL = URL(string: "wss://tu-dominio.com/socket")!

    init(url: URL = WS_URL) { self.url = url }

    @MainActor
    func connect(jwt: String, shopId: String, role: SocketRole) {
        self.jwt = jwt
        self.shopId = shopId
        self.role = role

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        task = session.webSocketTask(with: request)
        task?.resume()

        listen()
        sendAuth()
    }

    @MainActor
    func disconnect() {
        isConnected = false
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func sendAuth() {
        send(dict: ["type":"auth", "jwt": jwt, "shopId": shopId, "role": role.rawValue])
    }

    func sendCreateOrder(payload: [String: Any]) {
        send(dict: ["type": SocketEvent.orderCreate.rawValue, "shopId": shopId, "data": payload])
    }

    func send(dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { [weak self] error in
            if let error { self?.lastEvent = "send error: \(error.localizedDescription)" }
        }
    }

    private func listen() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                Task { @MainActor in
                    self.isConnected = false
                    self.lastEvent = "receive error: \(error.localizedDescription)"
                    self.reconnect()
                }
            case .success(let message):
                Task { @MainActor in self.handle(message) }
                self.listen()
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            lastEvent = text
            guard let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String
            else { return }

            switch type {
            case SocketEvent.authOK.rawValue:
                isConnected = true

            case SocketEvent.catalogUpdated.rawValue:
                if let data = json["data"] as? [String: Any],
                   let arr = data["products"] as? [[String: Any]] {
                    let mapped = arr.compactMap { dict -> Product? in
                        guard let id = dict["id"] as? String,
                              let name = dict["name"] as? String,
                              let imageName = dict["imageName"] as? String else { return nil }
                        return Product(id: id, name: name, imageName: imageName)
                    }
                    catalogSubject.send(mapped)
                }

            case SocketEvent.orderStatus.rawValue:
                if let data = json["data"] as? [String: Any],
                   let oid = data["orderId"] as? String,
                   let st  = data["status"] as? String {
                    orderStatusSubject.send((oid, st))
                }

            case SocketEvent.orderCreate.rawValue:                 // NEW: llega pedido del cliente
                guard let data = json["data"] as? [String: Any],
                      let itemsArr = data["items"] as? [[String: Any]],
                      let itemsData = try? JSONSerialization.data(withJSONObject: itemsArr)
                else { return }
                let decoder = JSONDecoder()
                if let items = try? decoder.decode([CartItem].self, from: itemsData) {
                    let order = ServerOrder(id: UUID().uuidString,
                                            items: items,
                                            createdAt: Date(),
                                            status: .pending)
                    orderIncomingSubject.send(order)

                    // Opcional: manda ACK al cliente
                    send(dict: ["type": SocketEvent.orderCreatedAck.rawValue,
                                "data": ["orderId": order.id]])
                }

            default: break
            }

        default:
            lastEvent = "binary message"
        }
    }

    private var retry = 0
    private func reconnect() {
        retry = min(retry + 1, 6)
        let delay = pow(2.0, Double(retry))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.connect(jwt: self.jwt, shopId: self.shopId, role: self.role)
        }
    }
}

// Helper ya usado por tu ServerProductsView
extension SocketService {
    func sendCatalog(_ products: [Product]) {
        let arr = products.map { ["id": $0.id, "name": $0.name, "imageName": $0.imageName] }
        let payload: [String: Any] = [
            "type": SocketEvent.catalogUpdated.rawValue,
            "data": ["products": arr, "shopId": shopId]
        ]
        send(dict: payload)
    }
}
