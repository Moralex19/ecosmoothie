//
//  VoiceAssistantView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 22/10/25.
//

// Voice/VoiceAssistantView.swift
import SwiftUI
import AVFoundation
import Speech
import Accelerate   // ⇦ para vDSP (cálculo de RMS)

struct VoiceAssistantView: View {
    @StateObject private var vm = VoiceAssistantViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("Asistente de Smoothies")
                .font(.title3.bold())

            // Transcripción parcial
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dijiste:")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(vm.partialTranscript.isEmpty ? "—" : vm.partialTranscript)
                        .font(.body)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("Respuesta:")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(vm.answer.isEmpty ? "—" : vm.answer)
                        .font(.body)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Nivel de audio (VU)
            ProgressView(value: vm.micLevel)
                .progressViewStyle(.linear)
                .tint(.green)

            HStack(spacing: 12) {
                Button {
                    Task { await vm.toggleRecording() }
                } label: {
                    Label(vm.isRecording ? "Escuchando..." : "Hablar",
                          systemImage: vm.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderedProminent)
                .tint(vm.isRecording ? .red : .accentColor)

                Button("Cerrar") {
                    vm.forceStop()
                }
            }
        }
        .padding()
        .onAppear {
            Task { await vm.prepare() }
        }
        .onDisappear {
            vm.forceStop()
        }
    }
}
