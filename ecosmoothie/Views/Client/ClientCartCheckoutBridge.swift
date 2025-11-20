//
//  ClientCartCheckoutBridge.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

import Foundation
import Combine

final class ClientCartCheckoutBridge: ObservableObject {
    private let socket: SocketService

    init(socket: SocketService) {
        self.socket = socket
    }

    func checkout(cartItems: [CartItem], customerName: String?) {
        // 🔹 Estructura personalizada para enviar al servidor
        let itemsPayload: [[String: Any]] = cartItems.map { ci in
            return [
                "productId": ci.product.id,
                "name": ci.product.name,
                "basePrice": ci.basePrice,
                "ingredients": ci.ingredients.map {
                    [
                        "productId": $0.productId,
                        "name": $0.name,
                        "unitPrice": $0.pricePerUnit,
                        "count": $0.count
                    ]
                },
                "total": ci.total
            ]
        }

        // 🔹 Total del pedido
        let total = cartItems.reduce(0) { $0 + $1.total }

        // 🔹 Payload base
        var payload: [String: Any] = [
            "items": itemsPayload,
            "total": total
        ]

        // 🔹 Añadimos el nombre del cliente solo si viene algo
        if let name = customerName,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["customerName"] = name
        }

        // 🔹 Log para ver exactamente qué se está mandando al servidor
        if JSONSerialization.isValidJSONObject(payload),
           let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
           let jsonString = String(data: data, encoding: .utf8) {
            print("📤 Payload createOrder que se envía al servidor:\n\(jsonString)")
        } else {
            print("❌ Payload no es un JSON válido, revisa las estructuras")
        }

        // 🔹 Enviar al servidor por socket
        socket.sendCreateOrder(payload: payload)
    }
}
