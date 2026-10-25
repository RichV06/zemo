import Foundation
import AstroCore

final class EngineTests {
    private let tmp = URL(fileURLWithPath: "/private/tmp")

    func testClaudeConsultIsReadOnlyAndPromptStaysOutOfArguments() throws {
        let request = try AgentRequest(prompt: "lista $(touch /tmp/x)", directory: tmp, mode: .consult, history: [], engine: .claude)
        let args = request.arguments
        XCTAssertTrue(args.contains("-p"))
        XCTAssertTrue(args.contains("stream-json"))
        XCTAssertTrue(args.contains("plan"))
        XCTAssertFalse(args.contains("acceptEdits"))
        XCTAssertFalse(args.contains("bypassPermissions"))
        XCTAssertFalse(args.contains("--dangerously-skip-permissions"))
        XCTAssertFalse(args.contains { $0.contains("touch") })
        XCTAssertTrue(request.input.contains("$(touch /tmp/x)"))
        if let index = args.firstIndex(of: "--tools") { XCTAssertFalse(args[index + 1].contains("Edit") || args[index + 1].contains("Write")) } else { XCTAssertTrue(false) }
        XCTAssertEqual(request.workingDirectory.path, "/tmp")
        XCTAssertEqual(request.engine, .claude)
    }

    func testClaudeEditAllowsFileEditsButNotArbitraryShell() throws {
        let request = try AgentRequest(prompt: "crea un README", directory: tmp, mode: .edit, history: [], engine: .claude)
        let args = request.arguments
        // acceptEdits aprueba solo rm/mv dentro de la carpeta: se prueba que no se use.
        XCTAssertFalse(args.contains("acceptEdits"))
        XCTAssertFalse(args.contains("bypassPermissions"))
        XCTAssertTrue(args.contains("Edit") && args.contains("Write"))
        XCTAssertFalse(args.contains("Bash"))
        XCTAssertFalse(args.contains("Bash(*)"))
        XCTAssertFalse(args.contains { $0.hasPrefix("Bash(rm") || $0.hasPrefix("Bash(curl") || $0.hasPrefix("Bash(gh api") })
    }

    func testClaudeAllowsOnlyReadConnectorsAndNoSlashCommands() throws {
        let args = try AgentRequest(prompt: "hola", directory: tmp, mode: .consult, history: [], engine: .claude).arguments
        XCTAssertTrue(args.contains("--disable-slash-commands"))
        XCTAssertFalse(args.contains("--dangerously-skip-permissions"))
        XCTAssertTrue(args.contains("mcp__claude_ai_Notion__notion-search"))
        XCTAssertFalse(args.contains { $0.contains("notion-update") || $0.contains("notion-create") || $0.contains("Gmail") })
    }

    func testGeminiModesNeverUseYolo() throws {
        let consult = try AgentRequest(prompt: "hola", directory: tmp, mode: .consult, history: [], engine: .gemini).arguments
        let edit = try AgentRequest(prompt: "hola", directory: tmp, mode: .edit, history: [], engine: .gemini).arguments
        XCTAssertTrue(consult.contains("plan"))
        XCTAssertTrue(edit.contains("auto_edit"))
        for args in [consult, edit] {
            XCTAssertFalse(args.contains("yolo"))
            XCTAssertFalse(args.contains("-y"))
            XCTAssertFalse(args.contains("--yolo"))
            XCTAssertTrue(args.contains("stream-json"))
            XCTAssertFalse(args.contains("hola"))
        }
    }

    func testEditStillRejectsBroadAndSensitiveFoldersForEveryEngine() {
        for engine in AgentEngine.allCases {
            XCTAssertThrowsError(try AgentRequest(prompt: "x", directory: URL(fileURLWithPath: NSHomeDirectory()), mode: .edit, history: [], engine: engine))
            XCTAssertThrowsError(try AgentRequest(prompt: "x", directory: URL(fileURLWithPath: NSHomeDirectory() + "/Library"), mode: .edit, history: [], engine: engine))
        }
    }

    func testCodexArgumentsAreUnchangedByDefault() throws {
        let request = try AgentRequest(prompt: "hola", directory: tmp, mode: .consult, history: [])
        XCTAssertEqual(request.engine, .codex)
        XCTAssertEqual(request.arguments.first, "exec")
        XCTAssertTrue(request.arguments.contains("read-only"))
    }

    func testEnginePromptDescribesWhatEachEngineCanReach() throws {
        let gemini = try AgentRequest(prompt: "hola", directory: tmp, mode: .consult, history: [], engine: .gemini).input
        XCTAssertTrue(gemini.contains("Gemini"))
        XCTAssertFalse(gemini.contains("sandbox de Codex"))
        let claude = try AgentRequest(prompt: "hola", directory: tmp, mode: .consult, history: [], engine: .claude).input
        XCTAssertTrue(claude.contains("Notion"))
    }

    func testChildEnvironmentOnlyForwardsTheEnginesOwnKeys() {
        let env = ["HOME": "/h", "PATH": "/bin", "ANTHROPIC_API_KEY": "a", "GEMINI_API_KEY": "g", "OPENAI_API_KEY": "o", "AWS_SECRET_ACCESS_KEY": "s", "GITHUB_TOKEN": "t"]
        let claude = ChildEnvironment.sanitized(env, engine: .claude)
        XCTAssertEqual(claude["ANTHROPIC_API_KEY"], "a")
        XCTAssertNil(claude["GEMINI_API_KEY"]); XCTAssertNil(claude["OPENAI_API_KEY"]); XCTAssertNil(claude["AWS_SECRET_ACCESS_KEY"]); XCTAssertNil(claude["GITHUB_TOKEN"])
        let gemini = ChildEnvironment.sanitized(env, engine: .gemini)
        XCTAssertEqual(gemini["GEMINI_API_KEY"], "g")
        XCTAssertNil(gemini["ANTHROPIC_API_KEY"]); XCTAssertNil(gemini["OPENAI_API_KEY"])
        let codex = ChildEnvironment.sanitized(env)
        XCTAssertEqual(codex["OPENAI_API_KEY"], "o")
        XCTAssertNil(codex["ANTHROPIC_API_KEY"]); XCTAssertNil(codex["GEMINI_API_KEY"])
    }

    func testParsesClaudeStream() {
        let text = #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"thinking","thinking":""},{"type":"text","text":"Hola"}]}}"#
        XCTAssertEqual(AgentEvent.parseAll(text, engine: .claude), [.message("Hola")])
        let bash = #"{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"git status"}}]}}"#
        XCTAssertEqual(AgentEvent.parseAll(bash, engine: .claude), [.command("git status")])
        let edit = #"{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Edit","input":{"file_path":"/a/b.txt"}}]}}"#
        XCTAssertEqual(AgentEvent.parseAll(edit, engine: .claude), [.activity("Archivo: /a/b.txt")])
        let result = #"{"type":"user","message":{"content":[{"type":"tool_result","content":"uno\ndos","is_error":false}]}}"#
        XCTAssertEqual(AgentEvent.parseAll(result, engine: .claude), [.output("uno\ndos", 0)])
        let blocks = #"{"type":"user","message":{"content":[{"type":"tool_result","content":[{"type":"text","text":"x"}],"is_error":true}]}}"#
        XCTAssertEqual(AgentEvent.parseAll(blocks, engine: .claude), [.output("x", 1)])
        XCTAssertEqual(AgentEvent.parseAll(#"{"type":"result","is_error":true,"result":"Sin sesión"}"#, engine: .claude), [.failure("Sin sesión")])
        XCTAssertEqual(AgentEvent.parseAll(#"{"type":"result","is_error":false,"result":"Hola"}"#, engine: .claude), [.finished])
        XCTAssertEqual(AgentEvent.parseAll(#"{"type":"system","subtype":"init"}"#, engine: .claude), [])
        XCTAssertEqual(AgentEvent.parseAll("no-json", engine: .claude), [])
    }

    func testParsesGeminiStream() {
        XCTAssertEqual(AgentEvent.parseAll(#"{"type":"message","role":"assistant","content":"hola","delta":true}"#, engine: .gemini), [.delta("hola")])
        XCTAssertEqual(AgentEvent.parseAll(#"{"type":"message","role":"assistant","content":"entero"}"#, engine: .gemini), [.message("entero")])
        XCTAssertEqual(AgentEvent.parseAll(#"{"type":"message","role":"user","content":"eco"}"#, engine: .gemini), [])
        XCTAssertEqual(AgentEvent.parseAll(#"{"type":"tool_use","tool_name":"run_shell_command","parameters":{"command":"ls"}}"#, engine: .gemini), [.command("ls")])
        XCTAssertEqual(AgentEvent.parseAll(#"{"type":"tool_use","tool_name":"read_file","parameters":{"file_path":"a"}}"#, engine: .gemini), [.activity("Herramienta: read_file")])
        XCTAssertEqual(AgentEvent.parseAll(#"{"type":"tool_use","tool_name":"update_topic","parameters":{}}"#, engine: .gemini), [])
        XCTAssertEqual(AgentEvent.parseAll(#"{"type":"tool_result","status":"success","output":"ok"}"#, engine: .gemini), [.output("ok", 0)])
        XCTAssertEqual(AgentEvent.parseAll(#"{"type":"result","status":"success"}"#, engine: .gemini), [.finished])
        XCTAssertEqual(AgentEvent.parseAll(#"{"type":"result","status":"error","error":{"message":"cuota"}}"#, engine: .gemini), [.failure("cuota")])
        XCTAssertEqual(AgentEvent.parseAll(#"{"type":"error","severity":"error","message":"falló"}"#, engine: .gemini), [.failure("falló")])
    }
}
