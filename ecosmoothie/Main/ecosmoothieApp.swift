//
//  ecosmoothieApp.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

import SwiftUI

@main
struct EcosmoothieApp: App {
    @StateObject private var session = SessionManager()
    @StateObject private var cart = CartStore()


    var body: some Scene {
        WindowGroup {
            RootView()
            .environmentObject(session)
            .environmentObject(cart)
        }
    }
}
