import SwiftUI
import AppKit

enum ZemoMood: String {
    case reposo, escucha, pensando, hablando, llamada, alerta, celebra, empuja

    var label: String {
        switch self {
        case .reposo: return "en reposo"
        case .escucha: return "escuchando"
        case .pensando: return "pensando"
        case .hablando: return "hablando"
        case .llamada: return "llamada entrante"
        case .alerta: return "alerta"
        case .celebra: return "celebrando un avance"
        case .empuja: return "empujando hacia adelante"
        }
    }
}

/// Hoja de sprites generada por `tools/sprites/build.py` (`Assets/sprites`).
final class SpriteSheet {
    struct StateInfo: Decodable { let row: Int; let frames: Int }
    struct Meta: Decodable { let frameSize: Int; let states: [String: StateInfo] }

    let image: CGImage
    let meta: Meta
    private var cache: [String: NSImage] = [:]

    static let shared: SpriteSheet? = SpriteSheet()

    static func resource(_ name: String, _ ext: String) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: ext) { return url }
        // Desarrollo con `swift run`: Assets/sprites junto al paquete.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("Assets/sprites/\(name).\(ext)")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private init?() {
        guard let sheetURL = Self.resource("zemo-sheet", "png"), let metaURL = Self.resource("frames", "json"),
              let source = CGImageSourceCreateWithURL(sheetURL as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let data = try? Data(contentsOf: metaURL), let meta = try? JSONDecoder().decode(Meta.self, from: data) else { return nil }
        self.image = image
        self.meta = meta
    }

    func frameCount(_ mood: ZemoMood) -> Int { meta.states[mood.rawValue]?.frames ?? 1 }

    func frame(_ mood: ZemoMood, _ index: Int) -> NSImage? {
        guard let info = meta.states[mood.rawValue] else { return nil }
        let column = min(max(index, 0), info.frames - 1)
        let key = "\(mood.rawValue)-\(column)"
        if let cached = cache[key] { return cached }
        let size = meta.frameSize
        guard let cropped = image.cropping(to: CGRect(x: column * size, y: info.row * size, width: size, height: size)) else { return nil }
        let result = NSImage(cgImage: cropped, size: NSSize(width: size, height: size))
        cache[key] = result
        return result
    }

    static func menubarImage() -> NSImage? {
        guard let url = resource("menubar@2x", "png"), let image = NSImage(contentsOf: url) else { return nil }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }
}

/// Sprite de Zemo: pixel art con escalado entero, sin interpolación.
struct SpriteView: View {
    var mood: ZemoMood
    var size: CGFloat = 192
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func frameIndex(_ mood: ZemoMood, at t: Double) -> Int {
        if reduceMotion { return mood == .pensando ? 1 : 0 }
        switch mood {
        case .reposo: return t.truncatingRemainder(dividingBy: 4.2) < 0.15 ? 1 : 0
        case .escucha: return t.truncatingRemainder(dividingBy: 3.1) < 0.15 ? 1 : 0
        case .pensando: return Int(t * 4) % 3
        case .hablando: return [0, 1, 2, 1, 0, 2, 1, 0][Int(t * 9) % 8]
        case .llamada: return Int(t * 3) % 2
        case .alerta: return Int(t * 2) % 2
        case .celebra: return Int(t * 3) % 2
        case .empuja: return Int(t * 2.5) % 2
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let pixel = size / 64
            let breath = (!reduceMotion && (mood == .reposo || mood == .escucha) && sin(t * 1.4) > 0.55) ? pixel : 0
            let shake = (!reduceMotion && mood == .llamada) ? (Int(t * 8) % 2 == 0 ? pixel : -pixel) : 0
            Group {
                if let sheet = SpriteSheet.shared, let frame = sheet.frame(mood, frameIndex(mood, at: t)) {
                    Image(nsImage: frame).resizable().interpolation(.none).frame(width: size, height: size)
                } else {
                    Image(systemName: "pawprint.fill").resizable().scaledToFit().frame(width: size * 0.6, height: size * 0.6)
                        .foregroundStyle(AstroTheme.orange).frame(width: size, height: size)
                }
            }
            .offset(x: shake, y: breath)
            .accessibilityLabel("Zemo, boyero australiano astronauta, \(mood.label)")
        }
        .frame(width: size, height: size)
    }
}
