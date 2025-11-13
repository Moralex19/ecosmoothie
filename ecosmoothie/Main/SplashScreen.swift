//
//  SplashScreen.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

import SwiftUI

struct SplashScreen: View {
    var onFinish: () -> Void
    
    @State private var iconOffsetY: CGFloat = -600 // inicia arriba
    
    
    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            
            
            ZStack {
                Color.almond
                    .ignoresSafeArea()
                /*
                LinearGradient(colors: [Color(.systemGray6), Color(.systemGray5)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                
                // Título fijo (ligeramente por debajo del centro)
                Text("ecoSmoothie")
                    .font(.system(size: min(W, H) * 0.08, weight: .bold, design: .rounded))
                    .kerning(1)
                    .foregroundStyle(.primary)
                    .shadow(radius: 2, y: 1)
                    .position(x: W/2, y: H * 0.58)
                */
                
                // Icono con halo que cae y rebota
                ZStack {
                    //Circle()
                       // .fill(Color.green.opacity(0.2))
                        //.frame(width: min(W, H) * 0.55, height: min(W, H) * 0.55)
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(W, H) * 0.58, height: min(W, H) * 0.58)
                }
                .position(x: W/2, y: (H * 0.42) + iconOffsetY)
            }
            .onAppear {
                // Caída con rebote
                withAnimation(.interpolatingSpring(stiffness: 120, damping: 10).delay(0.25)) {
                    iconOffsetY = 0
                }
                // Pequeño rebote adicional para sensación de pelota
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) { iconOffsetY = 12 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { iconOffsetY = 0 }
                    }
                }
                // Espera 3s y continúa a Auth
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { onFinish() }
            }
        }
        .preferredColorScheme(.light)
    }
}


#Preview {
    SplashScreen(onFinish: {})
        .frame(width: 430, height: 932)
}
