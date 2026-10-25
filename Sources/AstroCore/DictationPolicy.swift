import Foundation

public enum DictationPhase: Equatable { case idle, listening, finishing }
public enum DictationStart: Equatable { case started(Int), blockedByTask, alreadyActive }
public enum DictationOutcome: Equatable { case draft(String), noSpeech(restore: String), ignored }

/// Política de una sesión de dictado: conserva el borrador previo, descarta resultados de sesiones viejas
/// y nunca envía nada por sí misma. El reconocimiento real vive en la app.
public struct DictationPolicy {
    public static let maxDuration: TimeInterval = 60
    public private(set) var phase: DictationPhase = .idle
    private var session = 0
    private var base = ""
    public init() {}

    public var isBusy: Bool { phase != .idle }

    public mutating func start(draft: String, taskRunning: Bool) -> DictationStart {
        guard !taskRunning else { return .blockedByTask }
        guard phase == .idle else { return .alreadyActive }
        session += 1
        base = draft
        phase = .listening
        return .started(session)
    }

    public mutating func partial(_ text: String, session id: Int) -> String? {
        guard id == session, phase != .idle else { return nil }
        return compose(text)
    }

    public mutating func stop(session id: Int) -> Bool {
        guard id == session, phase == .listening else { return false }
        phase = .finishing
        return true
    }

    public mutating func finish(_ text: String, session id: Int) -> DictationOutcome {
        guard id == session, phase != .idle else { return .ignored }
        phase = .idle
        let spoken = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return spoken.isEmpty ? .noSpeech(restore: base) : .draft(compose(spoken))
    }

    /// Cancelación del usuario: devuelve el borrador anterior, o nil si no había sesión.
    public mutating func cancel() -> String? {
        guard phase != .idle else { return nil }
        phase = .idle
        session += 1
        return base
    }

    /// Fallo del reconocimiento: igual que cancelar, pero solo para la sesión vigente.
    public mutating func fail(session id: Int) -> String? {
        guard id == session, phase != .idle else { return nil }
        phase = .idle
        return base
    }

    private func compose(_ spoken: String) -> String {
        let spoken = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        let previous = base.trimmingCharacters(in: .whitespacesAndNewlines)
        return previous.isEmpty ? spoken : previous + " " + spoken
    }
}
