import Foundation
import Combine
import SwiftUI

@MainActor
final class ContentViewModel: ObservableObject {
    @Published var greeting: String = "Hello, world"

    func updateGreeting(to newGreeting: String) {
        greeting = newGreeting
    }
}
