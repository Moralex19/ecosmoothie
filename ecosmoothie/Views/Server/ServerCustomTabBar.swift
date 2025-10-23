//
//  ServerCustomTabBar.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 23/10/25.
//

// ServerCustomTabBar.swift
import SwiftUI
import UIKit

struct ServerCustomTabBar: View {
    @Binding var current: ServerMainTab
    var pendingBadge: Int = 0
    var onTap: (ServerMainTab) -> Void

    private let barHeight: CGFloat = 58
    private var bottomSafe: CGFloat {
        let win = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first { $0.isKeyWindow }
        return win?.safeAreaInsets.bottom ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color.black.opacity(0.08))
            HStack(spacing: 0) {
                item(.products, title: "Productos", sf: "shippingbox")
                item(.orders,   title: "Pedidos",   sf: "tray.full", badge: pendingBadge)
                item(.profile,  title: "Perfil",    sf: "person.crop.circle")
            }
            .frame(height: barHeight)
            .padding(.horizontal, 8)
            Color.clear.frame(height: bottomSafe)
        }
        .background(Color.almond.ignoresSafeArea(edges: .bottom))
    }

    @ViewBuilder
    private func item(_ tab: ServerMainTab, title: String, sf: String, badge: Int = 0) -> some View {
        let selected = current == tab
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.15)) { onTap(tab) }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: sf).font(.system(size: 20, weight: .semibold))
                    if tab == .orders, badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(.red))
                            .offset(x: 10, y: -8)
                    }
                }
                Text(title).font(.footnote)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(selected ? Color.matcha : Color.primary.opacity(0.55))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
