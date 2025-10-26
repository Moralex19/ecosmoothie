//
//  VoiceAssistantView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 22/10/25.
//

import SwiftUI
import AVFoundation
import Speech
import Accelerate

struct VoiceAssistantView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm: VoiceAssistantViewModel
    @State private var showHint = false

    // Guía de ejemplo para el usuario
    private let examplePrompt = "Ejemplo: di “beneficios del smoothie de mango”"

    // Evita pedir permisos/audio real en Preview
    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    // Init normal (app)
    @MainActor
    init() {
        _vm = StateObject(wrappedValue: VoiceAssistantViewModel())
    }

    // Init para Preview / inyección
    @MainActor
    init(previewModel: VoiceAssistantViewModel) {
        _vm = StateObject(wrappedValue: previewModel)
    }

    var body: some View {
        
        
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Asistente de Smoothies")
                    .font(.title3.bold())
                Text(examplePrompt)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Transcripción / Respuesta
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dijiste:")
                        .font(.caption).foregroundStyle(.secondary)

                    let transcriptText = vm.partialTranscript.isEmpty
                        ? (vm.isRecording ? "📣 \(examplePrompt)" : "—")
                        : vm.partialTranscript

                    Text(transcriptText)
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

            // Nivel del micrófono
            ProgressView(value: vm.micLevel)
                .progressViewStyle(.linear)
                .tint(.green)

            // Controles
            HStack(spacing: 12) {
                Button {
                    Task { await vm.toggleRecording() }
                    if !showHint {
                        showHint = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { showHint = false }
                        }
                    }
                } label: {
                    Label(vm.isRecording ? "Escuchando..." : "Hablar",
                          systemImage: vm.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderedProminent)
                .tint(vm.isRecording ? .red : .accentColor)

                Button {
                    vm.forceStop()  // detén audio
                    dismiss()       // cierra la sheet/pestaña
                } label: {
                    Label("Cerrar", systemImage: "xmark.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
            }

            if showHint {
                Text(examplePrompt)
                    .font(.footnote)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding()
        .onAppear {
            guard !isPreview else { return }
            Task { await vm.prepare() }
        }
        .onDisappear { vm.forceStop() }
        
    }
}

#Preview("Voice Assistant") {
    // VM de ejemplo: NO pide permisos en Preview
    let mock = VoiceAssistantViewModel()
    mock.isRecording = true
    mock.partialTranscript = "beneficios del smoothie de mango"
    mock.answer = "Smoothie de mango: vitaminas A/C/E, enzimas digestivas y antioxidantes; apoya vista, corazón y ánimo."
    mock.micLevel = 0.6

    return VoiceAssistantView(previewModel: mock)
        .preferredColorScheme(.dark)
}
