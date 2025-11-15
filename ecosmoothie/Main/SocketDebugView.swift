//
//  SocketDebugView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 14/11/25.
//

import SwiftUI

struct SocketDebugView: View {
    @EnvironmentObject var socket: SocketService

    var body: some View {
        VStack(spacing: 16) {
            Text(socket.isConnected ? "🟢 Conectado" : "🔴 Desconectado")
                .font(.title2)

            Text("Último evento:")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(socket.lastEvent)
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 120)
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button("Enviar pedido de prueba") {
                let payload: [String: Any] = [
                    "items": [
                        ["note": "batido de prueba desde iOS"]
                    ]
                ]
                socket.sendCreateOrder(payload: payload)
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    SocketDebugView()
        .environmentObject(SocketService())   // <- inyectas un SocketService de prueba
}

