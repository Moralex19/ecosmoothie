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

    func checkout(cartItems: [CartItem]) {
        let encoder = JSONEncoder()

        // CartItem debe ser Codable (igual que Product y IngredientCount)
        guard
            let itemsData = try? encoder.encode(cartItems),
            let itemsJSON = try? JSONSerialization.jsonObject(with: itemsData) as? [[String: Any]]
        else {
            print("❌ No se pudo serializar CartItem a JSON")
            return
        }

        let total = cartItems.reduce(0) { $0 + $1.total }

        let payload: [String: Any] = [
            "items": itemsJSON,
            "total": total
        ]

        socket.sendCreateOrder(payload: payload)
    }
}
