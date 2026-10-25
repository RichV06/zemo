import SwiftUI
import AstroCore

struct ChatView: View {
    @ObservedObject var model: ChatModel
    @FocusState private var inputFocused: Bool
    private let suggestions = ["¿Qué hay en esta carpeta?", "Explícame cómo ejecutar este proyecto", "Revisa el estado de Git", "¿Qué cabos sueltos tengo entre mis proyectos?"]

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 210)
            Rectangle().fill(AstroTheme.ink.opacity(0.09)).frame(width: 1)
            VStack(spacing: 0) {
                header
                Divider().overlay(AstroTheme.ink.opacity(0.06))
                conversation
                if model.showActivity { terminal.frame(height: 175) }
                composer
            }
            .background(AstroTheme.paper)
        }
        .foregroundStyle(AstroTheme.ink)
        .frame(minWidth: 700, minHeight: 610)
        .preferredColorScheme(.dark)
        .onAppear { inputFocused = true }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "sparkle").foregroundStyle(AstroTheme.orange)
                Text("Zemo").font(.system(size: 15, weight: .semibold, design: .monospaced))
            }.padding(.top, 22)
            SpriteView(mood: model.mood, size: 128).frame(maxWidth: .infinity).padding(.top, 14).padding(.bottom, 8)
            Text("Listo para\ntrabajar.")
                .font(.system(size: 23, weight: .medium, design: .monospaced)).lineSpacing(2)
            Text("Tu enlace con la terminal")
                .font(.system(size: 12)).foregroundStyle(AstroTheme.muted).padding(.top, 9)
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 10) {
                Label("Carpeta de la misión", systemImage: "folder").font(.system(size: 12, weight: .medium))
                Text(model.directory.lastPathComponent).font(.system(size: 13, weight: .semibold)).lineLimit(2)
                Text(model.directory.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(AstroTheme.muted).lineLimit(2).truncationMode(.middle)
                Button("Cambiar carpeta…", action: model.chooseDirectory)
                    .buttonStyle(.plain).foregroundStyle(AstroTheme.orange).font(.system(size: 12, weight: .medium))
                    .disabled(model.isRunning)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(AstroTheme.surface, in: RoundedRectangle(cornerRadius: 14))
            HStack(spacing: 6) {
                Circle().fill(model.executable == nil ? Color.red : AstroTheme.teal).frame(width: 6, height: 6)
                Text(model.executable == nil ? "\(model.engine.displayName) no encontrado" : "\(model.engine.displayName) disponible").font(.system(size: 10))
            }.foregroundStyle(AstroTheme.muted).padding(.top, 17).padding(.bottom, 22)
        }
        .padding(.horizontal, 18)
        .frame(maxHeight: .infinity)
        .background(AstroTheme.side)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Control de misión").font(.system(size: 18, weight: .semibold, design: .monospaced))
                HStack(spacing: 6) {
                    Circle().fill(model.hasError ? AstroTheme.orange : AstroTheme.teal).frame(width: 6, height: 6)
                    Text(model.status).font(.system(size: 11)).foregroundStyle(AstroTheme.muted)
                }.accessibilityElement(children: .combine)
            }
            Spacer()
            Button(action: { model.showActivity.toggle() }) { Image(systemName: "terminal").font(.system(size: 16)) }
                .buttonStyle(.plain).foregroundStyle(model.showActivity ? AstroTheme.orange : AstroTheme.muted)
                .help("Mostrar actividad de terminal").accessibilityLabel("Mostrar actividad de terminal")
            Button(action: model.clear) { Image(systemName: "square.and.pencil").font(.system(size: 16)) }
                .buttonStyle(.plain).padding(.leading, 10).disabled(model.isRunning)
                .help("Nueva conversación").accessibilityLabel("Nueva conversación")
        }.padding(.horizontal, 24).padding(.vertical, 20)
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if model.messages.isEmpty { welcome }
                    ForEach(model.messages) { message in
                        messageView(message).id(message.id)
                    }
                    if model.isRunning {
                        HStack(spacing: 9) {
                            ProgressView().controlSize(.small)
                            Text("Zemo está trabajando").font(.system(size: 12)).foregroundStyle(AstroTheme.muted)
                            if let date = model.taskStarted {
                                Text(date, style: .timer).monospacedDigit().font(.system(size: 11)).foregroundStyle(AstroTheme.muted)
                            }
                        }.padding(.vertical, 6)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }.padding(24)
            }
            .onChange(of: model.messages.count) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: model.isRunning) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "sun.max").foregroundStyle(AstroTheme.orange)
                Text("Terminal lista").font(.system(size: 11, weight: .medium)).foregroundStyle(AstroTheme.muted)
            }.padding(.top, 10)
            Text("¿Cuál es la misión?")
                .font(.system(size: 28, weight: .medium, design: .monospaced)).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            Text("Escribe una instrucción. Zemo ejecuta la tarea y te muestra lo que ocurre en la terminal.")
                .font(.system(size: 14)).foregroundStyle(AstroTheme.muted).lineSpacing(5).padding(.bottom, 10)
            ForEach(suggestions, id: \.self) { prompt in
                Button(action: { model.send(prompt) }) {
                    HStack {
                        Text(prompt).font(.system(size: 12))
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.system(size: 11)).foregroundStyle(AstroTheme.orange)
                    }.padding(.horizontal, 15).padding(.vertical, 13)
                        .background(AstroTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AstroTheme.ink.opacity(0.10)))
                }.buttonStyle(.plain).disabled(model.isRunning)
            }
        }
    }

    private func messageView(_ message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: message.role == "user" ? "person.crop.circle" : message.role == "error" ? "exclamationmark.circle" : "pawprint.fill")
                    .foregroundStyle(message.role == "error" ? Color.red : AstroTheme.orange)
                Text(message.role == "user" ? "Tú" : message.role == "error" ? "Necesito tu atención" : "Zemo")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Button(action: { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(message.text, forType: .string) }) {
                    Image(systemName: "doc.on.doc").font(.system(size: 10))
                }.buttonStyle(.plain).foregroundStyle(AstroTheme.muted).help("Copiar mensaje").accessibilityLabel("Copiar mensaje")
            }
            Text(message.text).font(.system(size: 13)).lineSpacing(5).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
        .padding(15).frame(maxWidth: .infinity, alignment: .leading)
        .background(message.role == "user" ? AstroTheme.side.opacity(0.75) : AstroTheme.surface, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(message.role == "error" ? Color.red.opacity(0.25) : .clear))
    }

    private var terminal: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "terminal")
                Text("Actividad de terminal")
                Spacer()
                Text("\(model.activity.count) eventos").foregroundStyle(.white.opacity(0.5))
            }.font(.system(size: 10, weight: .medium))
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 7) {
                        if model.activity.isEmpty { Text("Los comandos y su salida aparecerán aquí.").foregroundStyle(.white.opacity(0.55)) }
                        ForEach(model.activity) { line in
                            Text(line.text).foregroundStyle(line.isCommand ? Color(red: 1, green: 0.72, blue: 0.43) : .white.opacity(0.85)).id(line.id)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                }.onChange(of: model.activity.count) { _, _ in if let last = model.activity.last { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }.padding(14).background(AstroTheme.side).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 20).padding(.bottom, 12)
    }

    private var microphoneButton: some View {
        HStack(spacing: 6) {
            if model.isDictating {
                Button(action: model.cancelDictation) { Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).frame(width: 31, height: 31) }
                    .buttonStyle(.plain).foregroundStyle(AstroTheme.muted)
                    .help("Cancelar dictado (Esc)").accessibilityLabel("Cancelar dictado")
            }
            Button(action: model.toggleDictation) {
                Group {
                    if model.dictationPhase == .finishing { ProgressView().controlSize(.small) }
                    else { Image(systemName: model.dictationPhase == .listening ? "mic.fill" : "mic").font(.system(size: 14, weight: .semibold)) }
                }.frame(width: 31, height: 31)
            }
            .buttonStyle(.plain)
            .background(model.dictationPhase == .listening ? Color.red.opacity(0.85) : AstroTheme.ink.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
            .foregroundStyle(model.dictationPhase == .listening ? Color.white : AstroTheme.ink)
            .disabled(model.isRunning || model.dictationPhase == .finishing)
            .help(model.dictationPhase == .listening ? "Terminar dictado (⌃⌥Z)" : "Dictar por voz (⌃⌥Z)")
            .accessibilityLabel(model.dictationPhase == .listening ? "Terminar dictado" : "Dictar por voz")
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Menu {
                    Button("Consultar · sin cambios") { model.setMode(.consult) }
                    Button("Permitir cambios en la carpeta…") { model.setMode(.edit) }
                } label: {
                    Label(model.mode == .consult ? "Consultar" : "Editar carpeta", systemImage: model.mode == .consult ? "eye" : "pencil")
                        .font(.system(size: 11, weight: .medium))
                }.menuStyle(.borderlessButton).fixedSize().disabled(model.isRunning)
                Menu {
                    ForEach(AgentEngine.allCases, id: \.self) { engine in
                        Button(engine.displayName + (engine == model.engine ? " ✓" : "")) { model.setEngine(engine) }
                    }
                } label: {
                    Label(model.engine.displayName, systemImage: "cpu").font(.system(size: 11, weight: .medium))
                }.menuStyle(.borderlessButton).fixedSize().disabled(model.isRunning || model.isDictating)
                    .help("Motor de IA: quién procesa tus instrucciones")
                Spacer()
                Text(model.mode == .consult ? "Sin modificar archivos" : "Cambios habilitados").font(.system(size: 10)).foregroundStyle(AstroTheme.muted)
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Escríbele a Zemo…", text: $model.draft, axis: .vertical)
                    .textFieldStyle(.plain).font(.system(size: 14)).lineLimit(1...5).focused($inputFocused)
                    .onSubmit { model.send() }.disabled(model.isRunning || model.isDictating).accessibilityLabel("Instrucción para Zemo")
                microphoneButton
                if model.isRunning {
                    Button(action: model.stop) { Image(systemName: "stop.fill").frame(width: 31, height: 31) }
                        .buttonStyle(.plain).background(AstroTheme.orange, in: RoundedRectangle(cornerRadius: 9)).foregroundStyle(AstroTheme.side)
                        .help("Detener tarea").accessibilityLabel("Detener tarea")
                } else {
                    Button(action: { model.send() }) { Image(systemName: "arrow.up").font(.system(size: 14, weight: .semibold)).frame(width: 31, height: 31) }
                        .buttonStyle(.plain).background(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AstroTheme.muted.opacity(0.3) : AstroTheme.orange, in: RoundedRectangle(cornerRadius: 9)).foregroundStyle(AstroTheme.side)
                        .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isDictating).accessibilityLabel("Enviar instrucción")
                }
            }
            .padding(12).background(AstroTheme.surface, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(AstroTheme.ink.opacity(0.16)))
            if model.isDictating {
                Text(model.dictationPhase == .listening ? "● Escuchando · ⌃⌥Z para terminar · Esc para cancelar" : "Preparando la transcripción…")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(AstroTheme.orange).frame(maxWidth: .infinity)
            } else if !model.shortcutAvailable {
                Text("El atajo ⌃⌥Z está ocupado por otra app · usa el botón del micrófono")
                    .font(.system(size: 10)).foregroundStyle(AstroTheme.muted).frame(maxWidth: .infinity)
            }
            Text("Usa tu sesión de \(model.engine.displayName) · El texto se envía a \(model.engine.provider)")
                .font(.system(size: 9)).foregroundStyle(AstroTheme.muted).frame(maxWidth: .infinity)
        }.padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 17)
    }
}
