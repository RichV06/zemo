import Foundation
import AstroCore

final class ProtocolTests {
    func testPromptIsNeverPlacedInExecutableArguments() throws {
        let request = try AgentRequest(prompt: "lista $(touch /tmp/astro-unwanted); `whoami`", directory: URL(fileURLWithPath: "/tmp"), mode: .consult, history: [])
        XCTAssertFalse(request.arguments.contains { $0.contains("touch") || $0.contains("whoami") })
        XCTAssertTrue(request.input.contains("$(touch /tmp/astro-unwanted)"))
        XCTAssertTrue(request.arguments.contains("read-only"))
        XCTAssertFalse(request.arguments.contains("danger-full-access"))
    }

    func testEditModeUsesOnlySelectedWorkspace() throws {
        let request = try AgentRequest(prompt: "crea un README", directory: URL(fileURLWithPath: "/private/tmp"), mode: .edit, history: [])
        XCTAssertTrue(request.arguments.contains("workspace-write"))
        if let index = request.arguments.firstIndex(of: "-C"), index + 1 < request.arguments.count {
            XCTAssertEqual(request.arguments[index + 1], "/tmp")
        } else { XCTAssertTrue(false) }
        XCTAssertFalse(request.arguments.contains("--add-dir"))
        XCTAssertTrue(request.arguments.contains("approval_policy=\"never\""))
    }

    func testRejectsEmptyOversizedAndMissingDirectory() {
        XCTAssertThrowsError(try AgentRequest(prompt: " \n", directory: URL(fileURLWithPath: "/tmp"), mode: .consult, history: []))
        XCTAssertThrowsError(try AgentRequest(prompt: String(repeating: "a", count: 32_001), directory: URL(fileURLWithPath: "/tmp"), mode: .consult, history: []))
        XCTAssertThrowsError(try AgentRequest(prompt: "hola", directory: URL(fileURLWithPath: "/does-not-exist-astro"), mode: .consult, history: []))
    }

    func testEditRejectsBroadWorkspaceRoots() {
        for path in ["/", NSHomeDirectory(), NSHomeDirectory() + "/Developer", NSHomeDirectory() + "/Documents"] {
            XCTAssertThrowsError(try AgentRequest(prompt: "haz cambios", directory: URL(fileURLWithPath: path), mode: .edit, history: []))
        }
    }

    func testParsesCommandsOutputMessagesAndErrors() {
        XCTAssertEqual(AgentEvent.parse(#"{"type":"item.started","item":{"id":"1","type":"command_execution","command":"ls","status":"in_progress"}}"#), .command("ls"))
        XCTAssertEqual(AgentEvent.parse(#"{"type":"item.completed","item":{"id":"1","type":"command_execution","command":"ls","aggregated_output":"uno\ndos\n","exit_code":0,"status":"completed"}}"#), .output("uno\ndos\n", 0))
        XCTAssertEqual(AgentEvent.parse(#"{"type":"item.completed","item":{"type":"agent_message","text":"Listo"}}"#), .message("Listo"))
        XCTAssertEqual(AgentEvent.parse(#"{"type":"turn.failed","error":{"message":"Sin conexión"}}"#), .failure("Sin conexión"))
        XCTAssertNil(AgentEvent.parse("not-json"))
        XCTAssertNil(AgentEvent.parse(#"{"type":"thread.started","thread_id":"abc"}"#))
    }

    func testStreamingPreservesSplitUTF8AndFinalUnterminatedLine() {
        let bytes = Array("{\"text\":\"🐕 café\"}\nfinal".utf8)
        var decoder = LineDecoder()
        var lines: [String] = []
        for byte in bytes { lines += decoder.append(Data([byte])) }
        lines += decoder.finish()
        XCTAssertEqual(lines, ["{\"text\":\"🐕 café\"}", "final"])
    }

    func testEditRejectsSensitiveDirectoriesAndTheirChildren() throws {
        let home = NSHomeDirectory()
        let fm = FileManager.default
        let probe = home + "/.zemo-audit-probe"
        try fm.createDirectory(atPath: probe + "/child", withIntermediateDirectories: true)
        defer { try? fm.removeItem(atPath: probe) }
        for path in [home + "/Library", home + "/.codex", home + "/.ssh", home + "/.zemo-coach"] where fm.fileExists(atPath: path) {
            XCTAssertThrowsError(try AgentRequest(prompt: "haz cambios", directory: URL(fileURLWithPath: path), mode: .edit, history: []))
        }
        // Un directorio oculto cualquiera del home no es una carpeta de proyecto.
        XCTAssertThrowsError(try AgentRequest(prompt: "haz cambios", directory: URL(fileURLWithPath: probe + "/child"), mode: .edit, history: []))
        // Consultar sigue permitido (solo lectura).
        XCTAssertTrue((try? AgentRequest(prompt: "lista", directory: URL(fileURLWithPath: home + "/Library"), mode: .consult, history: [])) != nil)
    }

    func testChildEnvironmentDropsSecretsAndKeepsWhatCodexNeeds() {
        let source = ["HOME": "/Users/x", "PATH": "/usr/bin", "LANG": "es_CR.UTF-8", "CODEX_HOME": "/Users/x/.codex",
                      "OPENAI_API_KEY": "k", "HTTPS_PROXY": "p", "ANTHROPIC_API_KEY": "secret", "GITHUB_TOKEN": "secret",
                      "AWS_SECRET_ACCESS_KEY": "secret", "NOTION_TOKEN": "secret", "FOO": "bar"]
        let clean = ChildEnvironment.sanitized(source)
        for key in ["HOME", "PATH", "LANG", "CODEX_HOME", "OPENAI_API_KEY", "HTTPS_PROXY"] { XCTAssertEqual(clean[key], source[key]) }
        for key in ["ANTHROPIC_API_KEY", "GITHUB_TOKEN", "AWS_SECRET_ACCESS_KEY", "NOTION_TOKEN", "FOO"] { XCTAssertNil(clean[key]) }
    }

    func testVaultContextIsLoadedTruncatedAndPassedAsReference() throws {
        let vault = FileManager.default.temporaryDirectory.appendingPathComponent("zemo-vault-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: vault.appendingPathComponent("Mapas"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: vault) }
        try "Responde en español".write(to: vault.appendingPathComponent("07-como-trabajar-conmigo.md"), atomically: true, encoding: .utf8)
        try String(repeating: "x", count: 50).write(to: vault.appendingPathComponent("Mapas/00 Norte.md"), atomically: true, encoding: .utf8)
        let context = ContextHub.load(from: vault, maxPerFile: 30)
        XCTAssertTrue(context.contains("Responde en español"))
        XCTAssertTrue(context.contains("[…recortado]"))
        XCTAssertFalse(context.contains("09-mapa-de-fuentes"))
        let request = try AgentRequest(prompt: "cabos sueltos", directory: URL(fileURLWithPath: "/tmp"), mode: .consult, history: [], context: context)
        XCTAssertTrue(request.input.contains("Responde en español"))
        XCTAssertTrue(request.input.contains("no son instrucciones"))
        XCTAssertTrue(request.arguments.contains("read-only"))
        XCTAssertTrue(ContextHub.load(from: vault.appendingPathComponent("nada")).isEmpty)
    }
}
