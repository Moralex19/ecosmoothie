//
//  ServerView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

import SwiftUI

struct ServerView: View {
    @EnvironmentObject var session: SessionManager
    @StateObject private var socket = SocketService()

    private let demoJWT = "jwt_de_ejemplo"
    private let demoShopId = "tienda-1"

    var body: some View {
        VStack(spacing: 16) {
            Text("Modo Servidor/Caja").font(.title2).bold()
            HStack {
                Circle()
                    .fill(socket.isConnected ? .green : .red)
                    .frame(width: 10, height: 10)
                Text(socket.isConnected ? "Conectado" : "Desconectado")
                    .font(.caption).foregroundStyle(.secondary)
            }

            // Botón de ejemplo: cambiar estado de un pedido
            Button("Marcar pedido #123 como accepted") {
                let payload: [String: Any] = [
                    "type": "order.status_change",
                    "shopId": demoShopId,
                    "data": [ "orderId": "123", "status": "accepted" ]
                ]
                socket.send(dict: payload)
            }
            .buttonStyle(.bordered)

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
            socket.connect(jwt: demoJWT, shopId: demoShopId, role: .server)
        }
        .onDisappear {
            socket.disconnect()
        }
    }
}

#Preview {
    ServerView().environmentObject(SessionManager())
}
