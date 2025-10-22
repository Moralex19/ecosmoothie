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

/// Mensajes que nos interesan del backend
enum SocketEvent: String {
    case authOK           = "auth.ok"
    case catalogUpdated   = "catalog.updated"
    case orderCreatedAck  = "order.created_ack"
    case orderStatus      = "order.status_changed"
}

final class SocketService: ObservableObject {
    @Published var isConnected = false
    @Published var lastEvent: String = ""    // debug

    // Publishers para tu UI/Stores
    let catalogSubject = PassthroughSubject<[Product], Never>()
    let orderStatusSubject = PassthroughSubject<(orderId: String, status: String), Never>()

    private var task: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private let url: URL

    private var jwt: String = ""
    private var shopId: String = ""
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

    // MARK: - Send helpers

    private func sendAuth() {
        send(dict: ["type":"auth", "jwt": jwt, "shopId": shopId, "role": role.rawValue])
    }

    func sendCreateOrder(payload: [String: Any]) {
        // payload típico: { items:[...], total:123.0 }
        send(dict: ["type":"order.create", "shopId": shopId, "data": payload])
    }

    func send(dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { [weak self] error in
            if let error { self?.lastEvent = "send error: \(error.localizedDescription)" }
        }
    }

    // MARK: - Listen/Handle

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
                // Esperamos: { type:"catalog.updated", data:{ products:[{id,name,image,basePrice}, ...] } }
                if let data = json["data"] as? [String: Any],
                   let arr = data["products"] as? [[String: Any]] {
                    let mapped = arr.compactMap { dict -> Product? in
                        guard let id = dict["id"] as? String,
                              let name = dict["name"] as? String,
                              let imageName = dict["imageName"] as? String
                        else { return nil }
                        return Product(id: id, name: name, imageName: imageName)
                    }
                    catalogSubject.send(mapped)
                }

            case SocketEvent.orderStatus.rawValue:
                // { type:"order.status_changed", data:{ orderId, status } }
                if let data = json["data"] as? [String: Any],
                   let oid = data["orderId"] as? String,
                   let st  = data["status"] as? String {
                    orderStatusSubject.send((oid, st))
                }

            case SocketEvent.orderCreatedAck.rawValue:
                // Opcional: confirmar al cliente que se creó
                break

            default: break
            }

        default:
            lastEvent = "binary message"
        }
    }

    // MARK: - Reconnect

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
