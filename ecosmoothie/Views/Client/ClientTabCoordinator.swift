//
//  ClientTabCoordinator.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 22/10/25.
//

import SwiftUI
import Combine

enum ClientTab: CaseIterable, Hashable {
    case cart, orders, profile
}

final class ClientTabCoordinator: ObservableObject {
    @Published var currentTab: ClientTab = .orders

    func navigate(to tab: ClientTab) {
        guard currentTab != tab else { return }
        currentTab = tab
    }
}

