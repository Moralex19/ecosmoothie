//
//  ServerMainTab.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 23/10/25.
//

// ServerMainTab.swift
import SwiftUI
import Combine

/// Tabs del modo servidor (nombre único)
enum ServerMainTab: CaseIterable, Hashable {
    case products, orders, profile
}

/// Coordinador (nombre único)
final class ServerMainCoordinator: ObservableObject {
    @Published var current: ServerMainTab = .orders
    func navigate(to tab: ServerMainTab) { guard current != tab else { return }; current = tab }
}


