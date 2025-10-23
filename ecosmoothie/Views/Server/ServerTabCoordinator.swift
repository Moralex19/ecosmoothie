//
//  ServerTabCoordinator.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 23/10/25.
//

// ServerTabCoordinator.swift
import SwiftUI
import Combine

enum ServerTab: CaseIterable, Hashable {
    case products, orders, profile
}

final class ServerTabCoordinator: ObservableObject {
    @Published var current: ServerTab = .orders
    func navigate(to tab: ServerTab) {
        guard current != tab else { return }
        current = tab
    }
}

