import AppKit
import AVFoundation
import Carbon.HIToolbox
import Speech
import AstroCore

/// Captura de micrófono y reconocimiento local en español. No guarda audio ni transcripciones.
@MainActor
final class SpeechCapture {
    var onPartial: ((String) -> Void)?
    var onFinal: ((String) -> Void)?
    var onFailure: ((String) -> Void)?
    var onLimit: (() -> Void)?
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var limitTimer: Task<Void, Never>?
    private var finishTimer: Task<Void, Never>?
    private var generation = 0
    private var lastText = ""
    private var stopping = false

    /// Pide permisos solo la primera vez e inicia la captura. Devuelve un mensaje en español si no pudo.
    func start() async -> String? {
        if let problem = await Self.requestPermissions() { return problem }
        let locales = ["es-MX", "es-ES", "es-US"].map(Locale.init(identifier:))
        guard let recognizer = locales.lazy.compactMap({ SFSpeechRecognizer(locale: $0) }).first(where: { $0.isAvailable }) else {
            return "El reconocimiento de voz en español no está disponible ahora. Puedes seguir escribiendo."
        }
        guard recognizer.supportsOnDeviceRecognition else {
            return "Este Mac no tiene reconocimiento de voz local en español, y Zemo no envía audio a otros servicios. Actívalo en Ajustes del Sistema > Teclado > Dictado, o escribe tu instrucción."
        }
        teardown()
        generation += 1
        let current = generation
        lastText = ""
        stopping = false
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        self.request = request
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            teardown()
            return "No encuentro un micrófono disponible. Conéctalo o elígelo en Ajustes del Sistema > Sonido."
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
        do {
            engine.prepare()
            try engine.start()
        } catch {
            teardown()
            return "No pude abrir el micrófono: \(error.localizedDescription)"
        }
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let message = error?.localizedDescription
            Task { @MainActor in self?.handle(generation: current, text: text, isFinal: isFinal, error: message) }
        }
        limitTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(DictationPolicy.maxDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.onLimit?()
        }
        return nil
    }

    /// Cierra el micrófono y espera el resultado final del reconocedor.
    func stop() {
        guard request != nil, !stopping else { return }
        stopping = true
        limitTimer?.cancel()
        stopAudio()
        request?.endAudio()
        let current = generation
        finishTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled, let self, self.generation == current else { return }
            self.finalize(self.lastText)
        }
    }

    /// Libera todo sin avisar. Los resultados que lleguen después se descartan.
    func cancel() { teardown() }

    private func handle(generation current: Int, text: String?, isFinal: Bool, error: String?) {
        guard current == generation, request != nil else { return }
        if let text { lastText = text }
        if isFinal { finalize(lastText); return }
        if let error {
            if stopping { finalize(lastText) } else {
                teardown()
                onFailure?("El reconocimiento de voz falló: \(error)")
            }
            return
        }
        if let text { onPartial?(text) }
    }

    private func finalize(_ text: String) {
        teardown()
        onFinal?(text)
    }

    private func stopAudio() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
    }

    private func teardown() {
        generation += 1
        limitTimer?.cancel(); limitTimer = nil
        finishTimer?.cancel(); finishTimer = nil
        stopAudio()
        task?.cancel(); task = nil
        request = nil
        stopping = false
    }

    private static func requestPermissions() async -> String? {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .audio) else { return micDenied }
        default: return micDenied
        }
        var speech = SFSpeechRecognizer.authorizationStatus()
        if speech == .notDetermined {
            speech = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
        }
        return speech == .authorized ? nil : "Zemo no tiene permiso de reconocimiento de voz. Actívalo en Ajustes del Sistema > Privacidad y seguridad > Reconocimiento de voz. Puedes seguir escribiendo."
    }

    private static let micDenied = "Zemo no tiene permiso para usar el micrófono. Actívalo en Ajustes del Sistema > Privacidad y seguridad > Micrófono. Puedes seguir escribiendo."
}

/// Atajo global (Control + Opción + Z) sin permisos de accesibilidad.
final class GlobalHotKey {
    private var reference: EventHotKeyRef?
    private var handlerReference: EventHandlerRef?
    fileprivate let action: () -> Void

    /// Devuelve nil si otro programa ya ocupa la combinación.
    init?(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, _, userData in
            guard let userData else { return noErr }
            let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { hotKey.action() }
            return noErr
        }
        guard InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerReference) == noErr else { return nil }
        let id = EventHotKeyID(signature: OSType(0x5A454D4F), id: 1)
        guard RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &reference) == noErr else {
            if let handlerReference { RemoveEventHandler(handlerReference) }
            return nil
        }
    }

    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        if let handlerReference { RemoveEventHandler(handlerReference) }
    }
}
