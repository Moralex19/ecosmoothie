//
//  ClientView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

import SwiftUI

struct ClientView: View {
    @EnvironmentObject var session: SessionManager
    @StateObject private var socket = SocketService()

    // Valores de demo: cámbialos por los reales que guardes tras login
    private let demoJWT = "jwt_de_ejemplo"
    private let demoShopId = "tienda-1"

    var body: some View {
        VStack(spacing: 16) {
            Text("Modo Cliente").font(.title2).bold()
            HStack {
                Circle()
                    .fill(socket.isConnected ? .green : .red)
                    .frame(width: 10, height: 10)
                Text(socket.isConnected ? "Conectado" : "Desconectado")
                    .font(.caption).foregroundStyle(.secondary)
            }

            // Botón de ejemplo: enviar "crear pedido"
            Button("Enviar pedido (demo)") {
                let demoOrder: [String: Any] = [
                    "type": "order.create",
                    "shopId": demoShopId,
                    "data": [
                        "items": [
                            ["productId": "licuado-fresa", "qty": 1, "ingredientIds": ["chía","avena"]]
                        ]
                    ]
                ]
                socket.send(dict: demoOrder)
            }
            .buttonStyle(.borderedProminent)

            // Logs simples
            VStack(alignment: .leading) {
                Text("Último evento:")
                    .font(.footnote).foregroundStyle(.secondary)
                ScrollView {
                    Text(socket.lastEvent).font(.footnote).monospaced()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.frame(height: 140)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .onAppear {
            socket.connect(jwt: demoJWT, shopId: demoShopId, role: .client)
        }
        .onDisappear {
            socket.disconnect()
        }
    }
}

#Preview {
    ClientView().environmentObject(SessionManager())
}
