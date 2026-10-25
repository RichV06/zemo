import Foundation
import Darwin
import AstroCore

final class ProcessTests {
    func testStreamsStdoutStderrAndKeepsInputLiteral() throws {
        let runner = ProcessRunner()
        let done = DispatchSemaphore(value: 0)
        let capture = Capture()
        try runner.start(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "cat; echo diagnostic >&2"], input: "$(touch /tmp/astro-never-created) 🐕\n", onLine: { capture.add($0) }, onDiagnostic: { capture.add($0) }, completion: { result in
            capture.status = result.exitCode
            done.signal()
        })
        XCTAssertEqual(done.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(capture.status, 0)
        XCTAssertTrue(capture.lines.contains("$(touch /tmp/astro-never-created) 🐕"))
        XCTAssertTrue(capture.lines.contains("diagnostic"))
    }

    func testCancellationStopsProcessGroup() throws {
        let runner = ProcessRunner()
        let done = DispatchSemaphore(value: 0)
        let ready = DispatchSemaphore(value: 0)
        var wasCancelled = false
        try runner.start(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "sleep 30 & echo ready; wait"], input: "", onLine: { _ in ready.signal() }, onDiagnostic: { _ in }, completion: { result in
            wasCancelled = result.cancelled
            done.signal()
        })
        XCTAssertEqual(ready.wait(timeout: .now() + 3), .success)
        runner.cancel()
        XCTAssertEqual(done.wait(timeout: .now() + 3), .success)
        XCTAssertTrue(wasCancelled)
    }

    func testArgumentsAreAcceptedByInstalledCLI() throws {
        guard let cli = CodexLocator.find() else { print("SKIP: CLI compatibility (Codex not installed)"); return }
        for mode: AccessMode in [.consult, .edit] {
            let request = try AgentRequest(prompt: "hola", directory: URL(fileURLWithPath: "/tmp"), mode: mode, history: [])
            let done = DispatchSemaphore(value: 0)
            let runner = ProcessRunner()
            var status: Int32 = -1
            try runner.start(executable: cli, arguments: request.arguments + ["--help"], input: "", onLine: { _ in }, onDiagnostic: { _ in }, completion: { result in status = result.exitCode; done.signal() })
            XCTAssertEqual(done.wait(timeout: .now() + 10), .success)
            XCTAssertEqual(status, 0)
        }
    }

    func testMissingExecutableFailsImmediately() {
        let runner = ProcessRunner()
        XCTAssertThrowsError(try runner.start(executable: URL(fileURLWithPath: "/astro/no-executable"), arguments: [], input: "", onLine: { _ in }, onDiagnostic: { _ in }, completion: { _ in }))
    }
}

private final class Capture {
    private let lock = NSLock()
    private var storage: [String] = []
    var status: Int32 = -100
    var lines: [String] { lock.lock(); defer { lock.unlock() }; return storage }
    func add(_ line: String) { lock.lock(); storage.append(line); lock.unlock() }
}
