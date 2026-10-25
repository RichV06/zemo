import Foundation
import Darwin

public struct ProcessResult {
    public let exitCode: Int32
    public let cancelled: Bool
}

/// Each task owns a POSIX process group, so cancellation reaches its shell children too.
public final class ProcessRunner {
    private let lock = NSLock()
    private var pid: pid_t?
    private var cancelled = false
    private let callbacks = DispatchQueue(label: "astro.process.callbacks")
    public init() {}

    public func start(executable: URL, arguments: [String], input: String, engine: AgentEngine = .codex, workingDirectory: URL? = nil,
                      onLine: @escaping (String) -> Void,
                      onDiagnostic: @escaping (String) -> Void,
                      completion: @escaping (ProcessResult) -> Void) throws {
        lock.lock()
        defer { lock.unlock() }
        guard pid == nil else { throw NSError(domain: "Astro", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ya hay una tarea en curso."]) }
        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        posix_spawn_file_actions_init(&actions)
        posix_spawnattr_init(&attributes)
        defer { posix_spawn_file_actions_destroy(&actions); posix_spawnattr_destroy(&attributes) }
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP))
        posix_spawnattr_setpgroup(&attributes, 0)
        posix_spawn_file_actions_adddup2(&actions, stdin.fileHandleForReading.fileDescriptor, STDIN_FILENO)
        posix_spawn_file_actions_adddup2(&actions, stdout.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&actions, stderr.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
        for handle in [stdin.fileHandleForReading, stdin.fileHandleForWriting, stdout.fileHandleForReading, stdout.fileHandleForWriting, stderr.fileHandleForReading, stderr.fileHandleForWriting] {
            posix_spawn_file_actions_addclose(&actions, handle.fileDescriptor)
        }
        if let workingDirectory { posix_spawn_file_actions_addchdir_np(&actions, workingDirectory.path) }
        var environment = ChildEnvironment.sanitized(ProcessInfo.processInfo.environment, engine: engine)
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let nvmRoot = URL(fileURLWithPath: home + "/.nvm/versions/node")
        let nvmBins = ((try? FileManager.default.contentsOfDirectory(at: nvmRoot, includingPropertiesForKeys: nil)) ?? [])
            .sorted { $0.lastPathComponent.compare($1.lastPathComponent, options: .numeric) == .orderedDescending }
            .map { $0.appendingPathComponent("bin").path }
        environment["PATH"] = ([home + "/.local/bin", "/opt/homebrew/bin", "/usr/local/bin"] + nvmBins + [environment["PATH"] ?? "", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]).joined(separator: ":")
        let argv = ([executable.path] + arguments).map { strdup($0) } + [nil]
        let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { argv.forEach { free($0) }; envp.forEach { free($0) } }
        var child: pid_t = 0
        let code = argv.withUnsafeBufferPointer { args in
            envp.withUnsafeBufferPointer { env in
                posix_spawn(&child, executable.path, &actions, &attributes, args.baseAddress!, env.baseAddress!)
            }
        }
        guard code == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(code)) }
        pid = child
        cancelled = false
        try? stdin.fileHandleForReading.close()
        try? stdout.fileHandleForWriting.close()
        try? stderr.fileHandleForWriting.close()
        // A cancelled child may close stdin before the message is written.
        _ = fcntl(stdin.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
        let group = DispatchGroup()
        read(stdout.fileHandleForReading, group: group, deliver: onLine)
        read(stderr.fileHandleForReading, group: group, deliver: onDiagnostic)
        DispatchQueue.global(qos: .userInitiated).async {
            try? stdin.fileHandleForWriting.write(contentsOf: Data(input.utf8))
            try? stdin.fileHandleForWriting.close()
        }
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            var status: Int32 = 0
            while waitpid(child, &status, 0) == -1 && errno == EINTR {}
            group.wait()
            lock.lock()
            let stopped = cancelled
            pid = nil
            lock.unlock()
            let exitCode = (status & 0x7f) == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
            callbacks.async { completion(ProcessResult(exitCode: exitCode, cancelled: stopped)) }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 900) { [weak self] in self?.cancel() }
    }

    private func read(_ handle: FileHandle, group: DispatchGroup, deliver: @escaping (String) -> Void) {
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async { [callbacks] in
            defer { try? handle.close(); group.leave() }
            var decoder = LineDecoder()
            var delivered = 0
            var bytes = [UInt8](repeating: 0, count: 16_384)
            while true {
                let count = Darwin.read(handle.fileDescriptor, &bytes, bytes.count)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { break }
                let data = Data(bytes.prefix(count))
                for line in decoder.append(data) where delivered < 4_000 {
                    delivered += 1
                    callbacks.async { deliver(line) }
                }
            }
            for line in decoder.finish() where delivered < 4_000 { callbacks.async { deliver(line) } }
        }
    }

    public func cancel() {
        lock.lock()
        guard let processID = pid else { lock.unlock(); return }
        cancelled = true
        kill(-processID, SIGTERM)
        lock.unlock()
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) { [self] in
            lock.lock()
            if pid == processID { kill(-processID, SIGKILL) }
            lock.unlock()
        }
    }
}

public enum EngineLocator {
    public static func find(_ engine: AgentEngine) -> URL? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let name = engine.command
        var candidates = [home + "/.local/bin/" + name, "/opt/homebrew/bin/" + name, "/usr/local/bin/" + name]
        candidates += (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { "\($0)/" + name }
        let versions = URL(fileURLWithPath: home + "/.nvm/versions/node")
        candidates += ((try? fm.contentsOfDirectory(at: versions, includingPropertiesForKeys: nil)) ?? [])
            .sorted { $0.lastPathComponent.compare($1.lastPathComponent, options: .numeric) == .orderedDescending }
            .map { $0.appendingPathComponent("bin/" + name).path }
        return candidates.first(where: { fm.isExecutableFile(atPath: $0) }).map { URL(fileURLWithPath: $0) }
    }
}

public enum CodexLocator {
    public static func find() -> URL? { EngineLocator.find(.codex) }
}
