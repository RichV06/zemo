import AppKit
import SwiftUI
import Combine
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = ChatModel()
    var chatWindow: NSWindow!
    var petWindow: NSPanel!
    var statusItem: NSStatusItem!
    private var terminationSubscription: AnyCancellable?
    private var hotKey: GlobalHotKey?
    private var escapeMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        createMenu()
        chatWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 730), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        chatWindow.title = "Zemo"
        chatWindow.titlebarAppearsTransparent = true
        chatWindow.backgroundColor = NSColor(AstroTheme.paper)
        chatWindow.contentView = NSHostingView(rootView: ChatView(model: model))
        chatWindow.minSize = NSSize(width: 700, height: 640)
        chatWindow.isReleasedWhenClosed = false
        chatWindow.setFrameAutosaveName("ZemoChatWindow")
        chatWindow.center()
        createPet()
        showChat()
        hotKey = GlobalHotKey(keyCode: kVK_ANSI_Z, modifiers: controlKey | optionKey) { [weak self] in
            guard let self else { return }
            self.showChat()
            self.model.toggleDictation()
        }
        if hotKey == nil {
            model.shortcutAvailable = false
            model.messages.append(ChatMessage(role: "system", text: "Otro programa ya usa Control + Opción + Z, así que el atajo de voz no está activo. Puedes dictar con el botón del micrófono."))
        }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == UInt16(kVK_Escape), let model = self?.model, model.isDictating else { return event }
            model.cancelDictation()
            return nil
        }
    }

    func applicationWillTerminate(_ notification: Notification) { model.cancelDictation() }

    private func createPet() {
        let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        petWindow = NSPanel(contentRect: NSRect(x: frame.maxX - 224, y: frame.minY + 26, width: 200, height: 240), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        petWindow.backgroundColor = .clear
        petWindow.isOpaque = false
        petWindow.hasShadow = false
        petWindow.level = .floating
        petWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        petWindow.hidesOnDeactivate = false
        petWindow.isReleasedWhenClosed = false
        petWindow.contentView = NSHostingView(rootView: PetView(model: model, toggle: { [weak self] in self?.toggleChat() }, menu: { [weak self] in self?.petMenu() ?? NSMenu() }))
        petWindow.orderFrontRegardless()
    }

    private func createMenu() {
        let menu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Mostrar Zemo", action: #selector(showChat), keyEquivalent: "1")
        appMenu.addItem(withTitle: "Mostrar u ocultar mascota", action: #selector(togglePet), keyEquivalent: "2")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Salir de Zemo", action: #selector(quit), keyEquivalent: "q")
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let edit = NSMenu(title: "Edición")
        edit.addItem(withTitle: "Deshacer", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Cortar", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copiar", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Pegar", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Seleccionar todo", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem(title: "Edición", action: nil, keyEquivalent: "")
        editItem.submenu = edit
        menu.addItem(editItem)
        NSApp.mainMenu = menu
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = SpriteSheet.menubarImage() ?? NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Zemo")
        statusItem.button?.setAccessibilityLabel("Zemo")
        statusItem.menu = petMenu()
    }

    private func petMenu() -> NSMenu {
        let menu = NSMenu()
        for (title, action) in [("Hablar con Zemo", #selector(showChat)), ("Mostrar u ocultar mascota", #selector(togglePet)), ("Salir", #selector(quit))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        return menu
    }

    @objc func showChat() {
        chatWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    private func toggleChat() {
        if chatWindow.isVisible && NSApp.isActive { chatWindow.orderOut(nil) } else { showChat() }
    }
    @objc func togglePet() {
        if petWindow.isVisible { petWindow.orderOut(nil) } else { petWindow.orderFrontRegardless() }
    }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if model.isRunning {
            let alert = NSAlert()
            alert.messageText = "Hay una misión en curso"
            alert.informativeText = "Al salir, Zemo detendrá la tarea. Los cambios ya realizados se conservan."
            alert.addButton(withTitle: "Detener y salir")
            alert.addButton(withTitle: "Seguir trabajando")
            guard alert.runModal() == .alertFirstButtonReturn else { return .terminateCancel }
            terminationSubscription = model.$isRunning.dropFirst().filter { !$0 }.first().sink { _ in
                NSApp.reply(toApplicationShouldTerminate: true)
            }
            model.stop()
            return .terminateLater
        }
        return .terminateNow
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showChat(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

struct PetView: View {
    @ObservedObject var model: ChatModel
    let toggle: () -> Void
    let menu: () -> NSMenu
    var body: some View {
        VStack(spacing: 0) {
            SpriteView(mood: model.mood, size: 192)
            HStack(spacing: 5) {
                Circle().fill(model.hasError ? AstroTheme.orange : AstroTheme.teal).frame(width: 5, height: 5)
                Text(model.isRunning ? "En misión…" : model.hasError ? "Toca para revisar" : "Zemo · listo").font(.system(size: 10, weight: .medium, design: .monospaced))
            }.foregroundStyle(AstroTheme.ink).padding(.horizontal, 11).padding(.vertical, 6)
                .background(AstroTheme.paper, in: Capsule()).shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        }
        .frame(width: 200, height: 240)
        .overlay(DragSurface(toggle: toggle, menu: menu))
    }
}

struct DragSurface: NSViewRepresentable {
    let toggle: () -> Void
    let menu: () -> NSMenu
    func makeNSView(context: Context) -> PetDragView { let view = PetDragView(); view.toggle = toggle; view.makeMenu = menu; return view }
    func updateNSView(_ nsView: PetDragView, context: Context) {}
}
final class PetDragView: NSView {
    var toggle: (() -> Void)?
    var makeMenu: (() -> NSMenu)?
    private var initialMouse = NSPoint.zero
    private var initialOrigin = NSPoint.zero
    override func mouseDown(with event: NSEvent) { initialMouse = NSEvent.mouseLocation; initialOrigin = window?.frame.origin ?? .zero }
    override func mouseDragged(with event: NSEvent) {
        let current = NSEvent.mouseLocation
        var origin = NSPoint(x: initialOrigin.x + current.x - initialMouse.x, y: initialOrigin.y + current.y - initialMouse.y)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(current) }), let window {
            origin.x = min(max(origin.x, screen.visibleFrame.minX), screen.visibleFrame.maxX - window.frame.width)
            origin.y = min(max(origin.y, screen.visibleFrame.minY), screen.visibleFrame.maxY - window.frame.height)
        }
        window?.setFrameOrigin(origin)
    }
    override func mouseUp(with event: NSEvent) {
        let current = NSEvent.mouseLocation
        if hypot(current.x - initialMouse.x, current.y - initialMouse.y) < 5 { toggle?() }
    }
    override func rightMouseDown(with event: NSEvent) { if let menu = makeMenu?() { NSMenu.popUpContextMenu(menu, with: event, for: self) } }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityLabel() -> String? { "Zemo. Haz clic para abrir el chat; arrastra para mover." }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityPerformPress() -> Bool { toggle?(); return true }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
