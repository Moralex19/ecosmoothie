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

    init(url: URL = WS_URL) {
        self.url = url
    }

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

        print("🌐 SocketService.connect -> \(url.absoluteString) role=\(role.rawValue) shopId=\(shopId)")

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
        print("🔌 SocketService.disconnect()")
        shouldReconnect = false
        isConnected = false
        isConnecting = false
        stopPing()

        task?.cancel(with: .goingAway, reason: nil)
        task = nil

        retry = 0
    }

    // MARK: - Auth

    private func sendAuth() {
        let payload: [String: Any] = [
            "type": "auth",
            "jwt": jwt,
            "shopId": shopId,
            "role": role.rawValue
        ]
        print("📨 Enviando auth: \(payload)")
        send(dict: payload)
    }

    // MARK: - Envío createOrder

    func sendCreateOrder(payload: [String: Any]) {
        print("📤 Payload createOrder que se envía al servidor:")
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
           let txt = String(data: data, encoding: .utf8) {
            print(txt)
        }

        let wrapper: [String: Any] = [
            "type": SocketEvent.orderCreate.rawValue,
            "shopId": shopId,
            "data": payload
        ]

        print("📤 sendCreateOrder: \(wrapper)")
        send(dict: wrapper)
    }

    func send(dict: [String: Any]) {
        guard let task else { return }

        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]),
              let text = String(data: data, encoding: .utf8) else {
            return
        }

        print("➡️ SocketService.send TEXT:")
        print(text)

        task.send(.string(text)) { [weak self] error in
            if let error {
                print("❌ SocketService.send error: \(error)")
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
                print("❌ SocketService.receive error: \(error)")
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
            print("📩 Recibido TEXT:")
            print(text)
            DispatchQueue.main.async { self.lastEvent = text }

            guard let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else {
                return
            }

            switch type {

            case SocketEvent.authOK.rawValue:
                print("✅ auth.ok recibido")
                DispatchQueue.main.async {
                    self.isConnected = true
                    self.isConnecting = false
                    self.retry = 0
                }

            case SocketEvent.catalogUpdated.rawValue:
                handleCatalogUpdated(json: json)

            case SocketEvent.orderStatus.rawValue:
                handleOrderStatus(json: json)

            case SocketEvent.orderCreate.rawValue:
                handleOrderCreate(json: json)

            case SocketEvent.ordersSnapshot.rawValue:
                handleOrdersSnapshot(json: json)

            case SocketEvent.orderCreatedAck.rawValue:
                print("✅ order.created_ack recibido")
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

    // MARK: - Handlers

    private func handleCatalogUpdated(json: [String: Any]) {
        guard let data = json["data"] as? [String: Any],
              let arr  = data["products"] as? [[String: Any]] else { return }

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

    private func handleOrderStatus(json: [String: Any]) {
        if let data = json["data"] as? [String: Any],
           let oid  = data["orderId"] as? String,
           let st   = data["status"]   as? String {
            DispatchQueue.main.async {
                self.orderStatusSubject.send((oid, st))
            }
        }
    }

    /// order.create hacia la app servidor (cuando el backend notifica un nuevo pedido en tiempo real)
    private func handleOrderCreate(json: [String: Any]) {
        guard let dataDict = json["data"] as? [String: Any],
              let orderData = try? JSONSerialization.data(withJSONObject: dataDict)
        else { return }

        let decoder = Self.makeServerDecoder()

        do {
            let order = try decoder.decode(ServerOrder.self, from: orderData)
            DispatchQueue.main.async {
                self.orderIncomingSubject.send(order)
            }
        } catch {
            print("⚠️ No se pudo decodificar ServerOrder desde order.create: \(error)")
        }
    }

    /// orders.snapshot hacia la app servidor (cuando se conecta o reconecta)
    private func handleOrdersSnapshot(json: [String: Any]) {
        guard let data = json["data"] as? [String: Any],
              let arr  = data["orders"] as? [[String: Any]],
              let ordersData = try? JSONSerialization.data(withJSONObject: arr)
        else { return }

        let decoder = Self.makeServerDecoder()

        do {
            let orders = try decoder.decode([ServerOrder].self, from: ordersData)
            DispatchQueue.main.async {
                self.ordersSnapshotSubject.send(orders)
            }
        } catch {
            print("⚠️ No se pudo decodificar [ServerOrder] desde orders.snapshot: \(error)")
        }
    }

    // MARK: - Reconexión

    private func reconnect() {
        guard shouldReconnect else {
            print("🔌 reconnect: shouldReconnect = false, no reintento")
            return
        }

        retry = min(retry + 1, 6)
        let delay = pow(2.0, Double(retry))

        print("🔁 Intentando reconectar en \(delay)s (retry=\(retry))")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.shouldReconnect else { return }
            if self.isConnected || self.isConnecting {
                print("🔁 reconnect: ya conectado / conectando, cancelo intento")
                return
            }

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
                        print("❌ ping error: \(error)")
                        self.reconnect()
                    }
                } else {
                    print("🏓 ping OK")
                }
            }
        }
        if let pingTimer {
            RunLoop.main.add(pingTimer, forMode: .common)
        }
    }

    private func stopPing() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    // MARK: - Decoder para fechas del servidor

    /// El backend manda createdAt como "2025-11-20T17:56:47.854Z"
    /// Esto requiere ISO8601 con fracciones de segundo.
    private static func makeServerDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = iso.date(from: str) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Fecha inválida: \(str)"
            )
        }

        return decoder
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
