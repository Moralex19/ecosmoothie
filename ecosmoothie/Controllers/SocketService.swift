//
//  SocketService.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

import Foundation
import Combine

enum SocketRole: String { case client, server }

enum SocketEvent: String {
    case authOK           = "auth.ok"
    case catalogUpdated   = "catalog.updated"
    case orderCreatedAck  = "order.created_ack"
    case orderStatus      = "order.status_changed"
    case orderCreate      = "order.create"
    case ordersSnapshot   = "orders.snapshot"
}

final class SocketService: ObservableObject {
    @Published var isConnected = false
    @Published var lastEvent: String = ""

    let catalogSubject        = PassthroughSubject<[Product], Never>()
    let orderStatusSubject    = PassthroughSubject<(orderId: String, status: String), Never>()
    let orderIncomingSubject  = PassthroughSubject<ServerOrder, Never>()
    let ordersSnapshotSubject = PassthroughSubject<[ServerOrder], Never>()

    private var task: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private let url: URL

    private var jwt: String = ""
    var shopId: String = ""
    private var role: SocketRole = .client

    private var isConnecting = false
    private var shouldReconnect = false
    private var retry = 0
    private var pingTimer: Timer?

    static let WS_URL = URL(string: "ws://10.34.216.62:5050/ws")!

    init(url: URL = WS_URL) { self.url = url }

    deinit {
        stopPing()
        task?.cancel(with: .goingAway, reason: nil)
    }

    // MARK: - Conexión

    @MainActor
    func connect(jwt: String, shopId: String, role: SocketRole) {
        if isConnected || isConnecting { return }

        self.jwt = jwt
        self.shopId = shopId
        self.role = role
        self.shouldReconnect = true
        self.isConnecting = true

        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        let newTask = session.webSocketTask(with: request)
        self.task = newTask
        newTask.resume()

        listen()
        sendAuth()
        startPing()
    }

    @MainActor
    func disconnect() {
        shouldReconnect = false
        isConnected = false
        isConnecting = false
        stopPing()

        task?.cancel(with: .goingAway, reason: nil)
        task = nil

        retry = 0
    }

    // MARK: - Mensajería

    private func sendAuth() {
        send(dict: ["type":"auth", "jwt": jwt, "shopId": shopId, "role": role.rawValue])
    }

    func sendCreateOrder(payload: [String: Any]) {
        send(dict: ["type": SocketEvent.orderCreate.rawValue,
                    "shopId": shopId,
                    "data": payload])
    }

    func send(dict: [String: Any]) {
        guard let task else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }

        task.send(.string(text)) { [weak self] error in
            if let error {
                DispatchQueue.main.async {
                    self?.lastEvent = "send error: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Loop de recepción

    private func listen() {
        guard let task else { return }
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.isConnecting = false
                    self.lastEvent = "receive error: \(error.localizedDescription)"
                    self.reconnect()
                }
            case .success(let message):
                self.handle(message)
                self.listen()
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            DispatchQueue.main.async { self.lastEvent = text }

            guard let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else { return }

            switch type {
            case SocketEvent.authOK.rawValue:
                DispatchQueue.main.async {
                    self.isConnected = true
                    self.isConnecting = false
                    self.retry = 0
                }

            case SocketEvent.catalogUpdated.rawValue:
                if let data = json["data"] as? [String: Any],
                   let arr  = data["products"] as? [[String: Any]] {

                    let mapped = arr.compactMap { dict -> Product? in
                        guard let id   = dict["id"]   as? String,
                              let name = dict["name"] as? String
                        else { return nil }

                        let imageName = dict["imageName"] as? String ?? ""
                        let price     = dict["price"] as? Double ?? 0
                        let kindRaw   = dict["kind"] as? String ?? Product.Kind.smoothie.rawValue
                        let kind      = Product.Kind(rawValue: kindRaw) ?? .smoothie

                        return Product(id: id,
                                       name: name,
                                       imageName: imageName,
                                       price: price,
                                       kind: kind)
                    }

                    DispatchQueue.main.async {
                        self.catalogSubject.send(mapped)
                    }
                }

            case SocketEvent.orderStatus.rawValue:
                if let data = json["data"] as? [String: Any],
                   let oid  = data["orderId"] as? String,
                   let st   = data["status"]   as? String {
                    DispatchQueue.main.async {
                        self.orderStatusSubject.send((oid, st))
                    }
                }

            case SocketEvent.orderCreate.rawValue:
                guard let dataDict = json["data"] as? [String: Any],
                      let orderData = try? JSONSerialization.data(withJSONObject: dataDict)
                else { return }

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                if let order = try? decoder.decode(ServerOrder.self, from: orderData) {
                    DispatchQueue.main.async {
                        self.orderIncomingSubject.send(order)
                    }
                }

            case SocketEvent.ordersSnapshot.rawValue:
                guard let data = json["data"] as? [String: Any],
                      let arr  = data["orders"] as? [[String: Any]],
                      let ordersData = try? JSONSerialization.data(withJSONObject: arr)
                else { return }

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                if let orders = try? decoder.decode([ServerOrder].self, from: ordersData) {
                    DispatchQueue.main.async {
                        self.ordersSnapshotSubject.send(orders)
                    }
                }

            case SocketEvent.orderCreatedAck.rawValue:
                DispatchQueue.main.async {
                    self.lastEvent = text
                }

            default:
                break
            }

        default:
            DispatchQueue.main.async {
                self.lastEvent = "binary message"
            }
        }
    }

    // MARK: - Reconexión

    private func reconnect() {
        guard shouldReconnect else { return }
        retry = min(retry + 1, 6)
        let delay = pow(2.0, Double(retry))

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.shouldReconnect else { return }
            if self.isConnected || self.isConnecting { return }

            self.isConnecting = true
            var request = URLRequest(url: self.url)
            request.timeoutInterval = 30

            let newTask = self.session.webSocketTask(with: request)
            self.task = newTask
            newTask.resume()

            self.listen()
            self.sendAuth()
            self.startPing()
        }
    }

    // MARK: - Ping

    private func startPing() {
        stopPing()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            guard let self, let task = self.task else { return }
            task.sendPing { error in
                if let error {
                    DispatchQueue.main.async {
                        self.lastEvent = "ping error: \(error.localizedDescription)"
                        self.isConnected = false
                        self.isConnecting = false
                        self.reconnect()
                    }
                }
            }
        }
        RunLoop.main.add(pingTimer!, forMode: .common)
    }

    private func stopPing() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
}

// MARK: - Catálogo → socket

extension SocketService {
    func sendCatalog(_ products: [Product]) {
        let arr: [[String: Any]] = products.map {
            [
                "id": $0.id,
                "name": $0.name,
                "imageName": $0.imageName,
                "price": $0.price,
                "kind": $0.kind.rawValue
            ]
        }

        let payload: [String: Any] = [
            "type": SocketEvent.catalogUpdated.rawValue,
            "data": [
                "products": arr,
                "shopId": shopId
            ]
        ]
        send(dict: payload)
    }
}
