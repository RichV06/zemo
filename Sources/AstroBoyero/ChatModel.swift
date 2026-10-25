import AppKit
import SwiftUI
import AstroCore

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String
    var text: String
}
struct ActivityLine: Identifiable {
    let id = UUID()
    let text: String
    let isCommand: Bool
}

@MainActor
final class ChatModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var activity: [ActivityLine] = []
    @Published var draft = ""
    @Published var isRunning = false
    @Published var status = "Listo para explorar"
    @Published var hasError = false
    @Published var directory: URL
    @Published private(set) var mode: AccessMode = .consult
    @Published var showActivity = false
    @Published private(set) var engine: AgentEngine = ChatModel.savedEngine()
    @Published var executable: URL? = EngineLocator.find(ChatModel.savedEngine())
    @Published var taskStarted: Date?
    var mood: ZemoMood { hasError ? .alerta : isRunning ? .pensando : .reposo }
    private var runner: ProcessRunner?
    private var gotResponse = false
    private var diagnostics: [String] = []
    private var turns: [ConversationTurn] = []
    private var runID = UUID()
    private var streamingIndex: Int?
    @Published private(set) var dictationPhase: DictationPhase = .idle
    @Published var shortcutAvailable = true
    private var policy = DictationPolicy()
    private let capture = SpeechCapture()
    private var dictationID = 0
    private var captureReady = false
    var isDictating: Bool { dictationPhase != .idle }

    private static func savedEngine() -> AgentEngine {
        UserDefaults.standard.string(forKey: "ZemoEngine").flatMap(AgentEngine.init(rawValue:)) ?? .codex
    }

    func setEngine(_ value: AgentEngine) {
        guard !isRunning, !isDictating, value != engine else { return }
        engine = value
        UserDefaults.standard.set(value.rawValue, forKey: "ZemoEngine")
        executable = EngineLocator.find(value)
        status = "Motor: \(value.displayName)"
    }

    init() {
        let preferred = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Developer/zemo")
        directory = preferred
        capture.onPartial = { [weak self] text in self?.dictationPartial(text) }
        capture.onFinal = { [weak self] text in self?.dictationFinished(text) }
        capture.onFailure = { [weak self] message in self?.dictationFailed(message) }
        capture.onLimit = { [weak self] in self?.stopDictation() }
    }

    /// Atajo y botón: la primera pulsación escucha, la segunda termina y deja el texto en el borrador.
    func toggleDictation() {
        switch policy.phase {
        case .idle: startDictation()
        case .listening: captureReady ? stopDictation() : cancelDictation()
        case .finishing: break
        }
    }

    @Published private(set) var dictationLanguage: DictationLanguage =
        UserDefaults.standard.string(forKey: "ZemoDictationLanguage").flatMap(DictationLanguage.init(rawValue:)) ?? .spanish

    func setDictationLanguage(_ value: DictationLanguage) {
        guard !isDictating, value != dictationLanguage else { return }
        dictationLanguage = value
        UserDefaults.standard.set(value.rawValue, forKey: "ZemoDictationLanguage")
        status = "Dictado: \(value.displayName)"
    }

    private func startDictation() {
        switch policy.start(draft: draft, taskRunning: isRunning) {
        case .blockedByTask:
            status = "Espera a que termine la tarea para dictar"
        case .alreadyActive:
            break
        case .started(let id):
            dictationID = id
            captureReady = false
            dictationPhase = .listening
            status = "Preparando el micrófono…"
            Task { @MainActor in
                let problem = await capture.start(language: dictationLanguage)
                guard policy.phase == .listening, dictationID == id else { capture.cancel(); return }
                if let problem { dictationFailed(problem); return }
                captureReady = true
                status = "Escuchando… vuelve a pulsar para terminar"
            }
        }
    }

    func stopDictation() {
        guard captureReady, policy.stop(session: dictationID) else { return }
        dictationPhase = .finishing
        status = "Preparando la transcripción…"
        capture.stop()
    }

    func cancelDictation() {
        capture.cancel()
        captureReady = false
        guard let restored = policy.cancel() else { return }
        draft = restored
        dictationPhase = .idle
        status = "Dictado cancelado"
    }

    private func dictationPartial(_ text: String) {
        if let updated = policy.partial(text, session: dictationID) { draft = updated }
    }

    private func dictationFinished(_ text: String) {
        captureReady = false
        switch policy.finish(text, session: dictationID) {
        case .draft(let updated):
            draft = updated
            status = "Revisa el texto y pulsa Enter para enviarlo"
        case .noSpeech(let restored):
            draft = restored
            status = "No te escuché"
            messages.append(ChatMessage(role: "system", text: "No detecté voz. Pulsa el micrófono (o Control + Opción + Z) y vuelve a intentarlo, o escribe tu instrucción."))
        case .ignored:
            return
        }
        dictationPhase = .idle
    }

    private func dictationFailed(_ message: String) {
        capture.cancel()
        captureReady = false
        guard let restored = policy.fail(session: dictationID) else { return }
        draft = restored
        dictationPhase = .idle
        showError(message)
    }

    func send(_ text: String? = nil) {
        guard !isRunning, !isDictating else { return }
        let prompt = (text ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        let engine = self.engine
        executable = EngineLocator.find(engine)
        guard let executable else {
            showError("No encuentro \(engine.displayName). Instala su CLI e inicia sesión (en Terminal: \(engine.loginHint)); después vuelve a intentarlo.")
            return
        }
        do {
            let request = try AgentRequest(prompt: prompt, directory: directory, mode: mode, history: turns, context: ContextHub.load(), engine: engine)
            let worker = ProcessRunner()
            let id = UUID()
            runID = id
            runner = worker
            messages.append(ChatMessage(role: "user", text: prompt))
            turns.append(ConversationTurn(role: "user", text: prompt))
            draft = ""
            activity = []
            diagnostics = []
            gotResponse = false
            streamingIndex = nil
            hasError = false
            isRunning = true
            taskStarted = Date()
            status = "Preparando la misión…"
            try worker.start(executable: executable, arguments: request.arguments, input: request.input, engine: engine, workingDirectory: request.workingDirectory, onLine: { [weak self] line in
                DispatchQueue.main.async { guard let self, self.runID == id else { return }; self.receive(line) }
            }, onDiagnostic: { [weak self] line in
                DispatchQueue.main.async {
                    guard let self, self.runID == id else { return }
                    self.diagnostics.append(String(line.prefix(2_000)))
                    if self.diagnostics.count > 30 { self.diagnostics.removeFirst() }
                }
            }, completion: { [weak self] result in
                DispatchQueue.main.async {
                    guard let self, self.runID == id else { return }
                    self.closeStreaming()
                    self.isRunning = false
                    self.runner = nil
                    if result.cancelled {
                        self.status = "Misión detenida"
                        self.messages.append(ChatMessage(role: "system", text: "Tarea detenida. Los cambios ya realizados, si los hubo, se conservan."))
                    } else if result.exitCode != 0 || !self.gotResponse {
                        if !self.hasError {
                            let detail = self.diagnostics.suffix(5).joined(separator: "\n")
                            self.showError("\(engine.displayName) no pudo completar la tarea. Comprueba tu conexión y que hayas iniciado sesión (\(engine.loginHint))." + (detail.isEmpty ? "" : "\n\n" + detail))
                        }
                        self.status = "Necesito tu atención"
                    } else { self.status = self.hasError ? "Necesito tu atención" : "Misión completada" }
                }
            })
        } catch {
            isRunning = false
            runner = nil
            showError(error.localizedDescription)
        }
    }

    private func receive(_ line: String) {
        for event in AgentEvent.parseAll(line, engine: engine) { handle(event) }
    }

    private func handle(_ event: AgentEvent) {
        switch event {
        case .delta(let text):
            gotResponse = true
            if let index = streamingIndex, messages.indices.contains(index) { messages[index].text += text }
            else { messages.append(ChatMessage(role: "assistant", text: text)); streamingIndex = messages.count - 1 }
        case .finished:
            closeStreaming()
        case .message(let text):
            guard !text.isEmpty else { return }
            closeStreaming()
            gotResponse = true
            messages.append(ChatMessage(role: "assistant", text: String(text.prefix(100_000))))
            turns.append(ConversationTurn(role: "assistant", text: String(text.prefix(12_000))))
            if turns.count > 24 { turns.removeFirst(turns.count - 24) }
        case .command(let command):
            status = "Trabajando en la terminal…"
            addActivity("$ " + command, command: true)
        case .output(let text, let code):
            if !text.isEmpty { addActivity(text, command: false) }
            if let code, code != 0 { addActivity("Salida del comando: \(code)", command: false) }
        case .failure(let text): showError(text)
        case .activity(let text): addActivity(text, command: false)
        }
    }

    /// Cierra el mensaje que llegaba por fragmentos y lo agrega al historial enviado al modelo.
    private func closeStreaming() {
        guard let index = streamingIndex else { return }
        streamingIndex = nil
        guard messages.indices.contains(index) else { return }
        turns.append(ConversationTurn(role: "assistant", text: String(messages[index].text.prefix(12_000))))
        if turns.count > 24 { turns.removeFirst(turns.count - 24) }
    }

    private func addActivity(_ text: String, command: Bool) {
        activity.append(ActivityLine(text: String(text.prefix(16_000)), isCommand: command))
        if activity.count > 100 { activity.removeFirst(activity.count - 100) }
    }

    private func showError(_ message: String) {
        hasError = true
        status = "Necesito tu atención"
        messages.append(ChatMessage(role: "error", text: message))
    }

    func stop() { status = "Deteniendo…"; runner?.cancel() }

    func clear() {
        guard !isRunning, !isDictating else { return }
        messages = []; turns = []; activity = []; hasError = false; status = "Listo para explorar"
    }

    func chooseDirectory() {
        guard !isRunning, !isDictating else { return }
        let picker = NSOpenPanel()
        picker.title = "Elige la carpeta de tu misión"
        picker.canChooseDirectories = true
        picker.canChooseFiles = false
        picker.allowsMultipleSelection = false
        picker.directoryURL = directory
        guard picker.runModal() == .OK, let chosen = picker.url else { return }
        directory = chosen.resolvingSymlinksInPath()
        mode = .consult
        clear()
    }

    func setMode(_ value: AccessMode) {
        guard !isRunning, !isDictating, value != mode else { return }
        if value == .edit {
            do { _ = try AgentRequest(prompt: "validar", directory: directory, mode: .edit, history: []) }
            catch { showError(error.localizedDescription); return }
            let alert = NSAlert()
            alert.messageText = "Permitir cambios en esta carpeta"
            alert.informativeText = "Zemo podrá crear y modificar archivos en:\n\(directory.path)\n\nLas tareas se ejecutan con el sandbox de Codex y sin permisos elevados. Los cambios no se deshacen al detener una tarea."
            alert.addButton(withTitle: "Permitir cambios")
            alert.addButton(withTitle: "Cancelar")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        mode = value
    }
}
