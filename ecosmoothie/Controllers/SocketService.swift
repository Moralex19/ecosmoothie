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
    case orderCreate      = "order.create"         // broadcast desde el server hacia la app "caja"
    case ordersSnapshot   = "orders.snapshot"      // snapshot inicial para la app "caja"
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
    var shopId: String = ""                 // internal para sendCatalog
    private var role: SocketRole = .client

    // 🔒 Control de estado para evitar conexiones duplicadas + reconexión controlada
    private var isConnecting = false
    private var shouldReconnect = false
    private var retry = 0
    private var pingTimer: Timer?

    static let WS_URL = URL(string: "ws://localhost:5050/ws")!

    init(url: URL = WS_URL) { self.url = url }

    deinit {
        stopPing()
        task?.cancel(with: .goingAway, reason: nil)
    }

    // MARK: - Conexión

    /// Conecta si no hay una conexión vigente o en progreso.
    @MainActor
    func connect(jwt: String, shopId: String, role: SocketRole) {
        // Evita conexiones duplicadas que causan "lag"
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

    /// Desconecta y detiene reconexión/keep-alive.
    @MainActor
    func disconnect() {
        shouldReconnect = false             // ← no volver a reconectar
        isConnected = false
        isConnecting = false
        stopPing()

        task?.cancel(with: .goingAway, reason: nil)
        task = nil

        retry = 0                           // ← corta reconexiones en segundo plano
    }

    // MARK: - Mensajería

    private func sendAuth() {
        send(dict: ["type":"auth", "jwt": jwt, "shopId": shopId, "role": role.rawValue])
    }

    /// Cliente (app consumidor) envía un pedido al backend
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
                // Maneja y sigue escuchando
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
                   let arr = data["products"] as? [[String: Any]] {
                    let mapped = arr.compactMap { dict -> Product? in
                        guard let id = dict["id"] as? String,
                              let name = dict["name"] as? String,
                              let imageName = dict["imageName"] as? String else { return nil }
                        return Product(id: id, name: name, imageName: imageName)
                    }
                    DispatchQueue.main.async {
                        self.catalogSubject.send(mapped)
                    }
                }

            case SocketEvent.orderStatus.rawValue:
                if let data = json["data"] as? [String: Any],
                   let oid = data["orderId"] as? String,
                   let st  = data["status"] as? String {
                    DispatchQueue.main.async {
                        self.orderStatusSubject.send((oid, st))
                    }
                }

            case SocketEvent.orderCreate.rawValue:
                // Pedido nuevo broadcast desde el backend hacia la app "caja"
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
                // Snapshot inicial de pedidos cuando la app se conecta como servidor
                guard let data = json["data"] as? [String: Any],
                      let arr = data["orders"] as? [[String: Any]],
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
                // Si quieres, aquí podrías actualizar UI del cliente con el orderId real
                // Por ahora solo lo mostramos en lastEvent
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

    // MARK: - Reconexión exponencial (respetando flags)

    private func reconnect() {
        guard shouldReconnect else { return }        // ← no reconectar si se llamó disconnect()
        retry = min(retry + 1, 6)
        let delay = pow(2.0, Double(retry))         // 2,4,8,16,32,64 (seg máx ~64)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.shouldReconnect else { return }
            // Evita múltiples reconexiones si ya se reconectó por otro lado
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

    // MARK: - Keep-alive (ping)

    private func startPing() {
        stopPing()
        // Ping cada 20s para mantener viva la conexión detrás de NAT/firewalls
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
        // Evitar que el timer bloquee la UI
        RunLoop.main.add(pingTimer!, forMode: .common)
    }

    private func stopPing() {
        pingTimer?.invalidate()
        pingTimer = nil
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
