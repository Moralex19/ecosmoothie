//
//  ClientCartCheckoutBridge.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

// ClientCartCheckoutBridge.swift
// ClientCartCheckoutBridge.swift
import Foundation
import Combine

final class ClientCartCheckoutBridge: ObservableObject {
    private let socket: SocketService

    init(socket: SocketService) { self.socket = socket }

    func checkout(cartItems: [CartItem]) {
        let itemsPayload: [[String: Any]] = cartItems.map { ci in
            [
                "productId": ci.product.id,
                "name": ci.product.name,
                "basePrice": ci.basePrice,
                "ingredients": ci.ingredients.map {
                    ["name": $0.kind.rawValue, "count": $0.count, "unitPrice": $0.pricePerUnit]
                },
                "total": ci.total
            ]
        }
        let total = cartItems.reduce(0) { $0 + $1.total }

        socket.sendCreateOrder(payload: [
            "items": itemsPayload,
            "total": total
        ])
    }
}
