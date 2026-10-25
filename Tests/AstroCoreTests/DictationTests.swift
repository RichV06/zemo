import Foundation
import AstroCore

final class DictationTests {
    func testStartPreservesDraftAndAppendsPartialResults() {
        var policy = DictationPolicy()
        guard case .started(let id) = policy.start(draft: "revisa", taskRunning: false) else { return XCTAssertTrue(false) }
        XCTAssertEqual(policy.phase, .listening)
        XCTAssertEqual(policy.partial("el estado", session: id), "revisa el estado")
        XCTAssertEqual(policy.partial("el estado de git", session: id), "revisa el estado de git")
    }

    func testEmptyDraftHasNoLeadingSpace() {
        var policy = DictationPolicy()
        guard case .started(let id) = policy.start(draft: "  ", taskRunning: false) else { return XCTAssertTrue(false) }
        XCTAssertEqual(policy.partial("hola", session: id), "hola")
    }

    func testStopThenFinalLeavesEditableDraftAndGoesIdle() {
        var policy = DictationPolicy()
        guard case .started(let id) = policy.start(draft: "", taskRunning: false) else { return XCTAssertTrue(false) }
        XCTAssertTrue(policy.stop(session: id))
        XCTAssertEqual(policy.phase, .finishing)
        XCTAssertEqual(policy.finish("lista la carpeta", session: id), .draft("lista la carpeta"))
        XCTAssertEqual(policy.phase, .idle)
    }

    func testEmptyResultRestoresDraftAndReportsNoSpeech() {
        var policy = DictationPolicy()
        guard case .started(let id) = policy.start(draft: "previo", taskRunning: false) else { return XCTAssertTrue(false) }
        _ = policy.partial("ruido", session: id)
        XCTAssertEqual(policy.finish("  ", session: id), .noSpeech(restore: "previo"))
        XCTAssertEqual(policy.phase, .idle)
    }

    func testCancelRestoresPreviousDraftAndIgnoresLateResults() {
        var policy = DictationPolicy()
        guard case .started(let id) = policy.start(draft: "previo", taskRunning: false) else { return XCTAssertTrue(false) }
        _ = policy.partial("algo dicho", session: id)
        XCTAssertEqual(policy.cancel(), "previo")
        XCTAssertEqual(policy.phase, .idle)
        XCTAssertNil(policy.partial("tarde", session: id))
        XCTAssertEqual(policy.finish("tarde", session: id), .ignored)
    }

    func testLateResultFromPreviousSessionDoesNotTouchNewSession() {
        var policy = DictationPolicy()
        guard case .started(let first) = policy.start(draft: "", taskRunning: false) else { return XCTAssertTrue(false) }
        _ = policy.cancel()
        guard case .started(let second) = policy.start(draft: "nuevo", taskRunning: false) else { return XCTAssertTrue(false) }
        XCTAssertTrue(first != second)
        XCTAssertNil(policy.partial("viejo", session: first))
        XCTAssertEqual(policy.finish("viejo", session: first), .ignored)
        XCTAssertEqual(policy.phase, .listening)
        XCTAssertEqual(policy.partial("fresco", session: second), "nuevo fresco")
    }

    func testBlockedWhileTaskRunningOrAlreadyActive() {
        var policy = DictationPolicy()
        XCTAssertEqual(policy.start(draft: "", taskRunning: true), .blockedByTask)
        XCTAssertEqual(policy.phase, .idle)
        guard case .started = policy.start(draft: "", taskRunning: false) else { return XCTAssertTrue(false) }
        XCTAssertEqual(policy.start(draft: "", taskRunning: false), .alreadyActive)
    }

    func testFailureRestoresDraftAndCancelWhenIdleIsHarmless() {
        var policy = DictationPolicy()
        XCTAssertNil(policy.cancel())
        guard case .started(let id) = policy.start(draft: "previo", taskRunning: false) else { return XCTAssertTrue(false) }
        _ = policy.partial("parcial", session: id)
        XCTAssertEqual(policy.fail(session: id), "previo")
        XCTAssertEqual(policy.phase, .idle)
        XCTAssertNil(policy.fail(session: id))
    }

    func testSessionLimitIsSixtySeconds() {
        XCTAssertEqual(DictationPolicy.maxDuration, 60)
    }

    func testBusyWhileListeningOrFinishing() {
        var policy = DictationPolicy()
        XCTAssertFalse(policy.isBusy)
        guard case .started(let id) = policy.start(draft: "", taskRunning: false) else { return XCTAssertTrue(false) }
        XCTAssertTrue(policy.isBusy)
        _ = policy.stop(session: id)
        XCTAssertTrue(policy.isBusy)
        _ = policy.finish("x", session: id)
        XCTAssertFalse(policy.isBusy)
    }

    func testSpanishCandidatesPutSystemLanguagesFirstWithoutDuplicates() {
        let list = DictationPolicy.spanishLocales(preferred: ["en-CR", "es_CR", "es-MX"])
        XCTAssertEqual(Array(list.prefix(2)), ["es-CR", "es-MX"])
        XCTAssertEqual(list.count, Set(list).count)
        XCTAssertTrue(list.allSatisfy { $0.hasPrefix("es-") })
        XCTAssertTrue(list.contains("es-419") && list.contains("es-ES") && list.contains("es-US"))
    }

    func testPicksFirstSpanishLocaleThatWorksOnDevice() {
        let list = ["es-CR", "es-MX", "es-ES"]
        XCTAssertEqual(DictationPolicy.firstOnDevice(in: list) { $0 == "es-ES" }, "es-ES")
        XCTAssertEqual(DictationPolicy.firstOnDevice(in: list) { _ in true }, "es-CR")
        XCTAssertEqual(DictationPolicy.firstOnDevice(in: list) { _ in false }, nil)
    }

    func testEnglishCandidatesUseOnlyEnglishVariantsAndSystemOnesFirst() {
        let list = DictationPolicy.locales(for: .english, preferred: ["en-CR", "en_GB", "es-CR"])
        XCTAssertEqual(Array(list.prefix(2)), ["en-CR", "en-GB"])
        XCTAssertEqual(list.count, Set(list).count)
        XCTAssertTrue(list.allSatisfy { $0.hasPrefix("en-") })
        XCTAssertTrue(list.contains("en-US"))
        XCTAssertEqual(DictationPolicy.locales(for: .spanish, preferred: ["es_CR"]).first, "es-CR")
    }

    func testDictationLanguageIsSavedByRawValueWithSpanishDefault() {
        XCTAssertEqual(DictationLanguage(rawValue: "en"), .english)
        XCTAssertEqual(DictationLanguage(rawValue: "es"), .spanish)
        XCTAssertNil(DictationLanguage(rawValue: "fr"))
        XCTAssertEqual(DictationLanguage.spanish.displayName, "Español")
        XCTAssertEqual(DictationLanguage.english.displayName, "English")
    }
}
