//
//  VoiceAssitentViewModel.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 22/10/25.
//

// VoiceAssistantViewModel.swift
import Foundation
import AVFoundation
import Speech
import Accelerate
import Combine

@MainActor
final class VoiceAssistantViewModel: NSObject, ObservableObject {
    // UI
    @Published var isRecording = false
    @Published var partialTranscript = ""
    @Published var answer = ""
    @Published var micLevel: Float = 0  // 0..1 aprox

    // Audio / STT / TTS
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-MX"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let synthesizer = AVSpeechSynthesizer()

    // Silencio
    private let silenceThresholdDB: Float = -45
    private let maxSilenceDuration: TimeInterval = 1.5
    private var lastLoudDate = Date()

    // MARK: Public API (lo que llama tu vista)
    func prepare() async {
        let micOk = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            AVAudioSession.sharedInstance().requestRecordPermission { c.resume(returning: $0) }
        }
        let speech = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard micOk, speech == .authorized else {
            answer = "No tengo permisos de micrófono o voz."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.defaultToSpeaker, .duckOthers, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            answer = "No pude configurar audio: \(error.localizedDescription)"
        }
    }

    func toggleRecording() async {
        if isRecording { stopRecording(finalize: true) }
        else { await startRecording() }
    }

    func forceStop() {
        stopRecording(finalize: false)
    }

    // MARK: Grabación
    private func startRecording() async {
        guard !isRecording else { return }
        partialTranscript = ""
        answer = ""
        micLevel = 0

        do {
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            recognitionRequest = request

            guard let recognizer = speechRecognizer, recognizer.isAvailable else {
                answer = "Reconocimiento de voz no disponible."
                return
            }

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    self.partialTranscript = result.bestTranscription.formattedString
                    if result.isFinal { self.stopRecording(finalize: true) }
                }
                if error != nil { self.stopRecording(finalize: true) }
            }

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)

            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                guard let self else { return }
                self.recognitionRequest?.append(buffer)

                // medir potencia
                let db = buffer.rmsPowerDB()
                DispatchQueue.main.async {
                    self.micLevel = min(max((db + 50) / 50, 0), 1) // normalizar
                    if db > self.silenceThresholdDB { self.lastLoudDate = Date() }
                    if self.isRecording && Date().timeIntervalSince(self.lastLoudDate) > self.maxSilenceDuration {
                        self.stopRecording(finalize: true)
                    }
                }
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
            lastLoudDate = Date()
        } catch {
            stopRecording(finalize: false)
            answer = "No pude iniciar el audio: \(error.localizedDescription)"
        }
    }

    private func stopRecording(finalize: Bool) {
        guard isRecording else { return }
        isRecording = false

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        if finalize { Task { await answerAndSpeak() } }
    }

    // MARK: Responder + TTS
    private func answerAndSpeak() async {
        let text = makeAnswer(from: partialTranscript)
        answer = text
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "es-MX")
        synthesizer.speak(u)
    }

    private func makeAnswer(from query: String) -> String {
        let q = query.lowercased()
        if q.contains("fresa") {
            return "La fresa aporta vitamina C y antioxidantes; apoya defensas y piel."
        } else if q.contains("mango") {
            return "El mango es rico en vitaminas A y C y fibra, bueno para visión y digestión."
        } else if q.contains("kiwi") {
            return "El kiwi tiene mucha vitamina C y fibra; ayuda al sistema inmune."
        } else if q.contains("durazno") {
            return "El durazno hidrata y aporta vitaminas A y C, ideal para piel."
        } else if q.contains("café") {
            return "Con café obtienes energía y enfoque por la cafeína, útil como pre-entreno."
        }
        return "Puedo darte beneficios de smoothies y extras. Pregunta por una fruta específica."
    }
}

// MARK: - RMS (Accelerate)
private extension AVAudioPCMBuffer {
    func rmsPowerDB() -> Float {
        guard let ch0 = self.floatChannelData?.pointee else { return -120 }
        let n = vDSP_Length(self.frameLength)
        if n == 0 { return -120 }
        var meanSquare: Float = 0
        vDSP_measqv(ch0, 1, &meanSquare, n)
        let rms = sqrtf(meanSquare)
        return 20 * log10f(max(rms, 1e-7))
    }
}
