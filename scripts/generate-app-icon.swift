#!/usr/bin/env swift
//
// generate-app-icon.swift
//
// Lumark 앱 아이콘(방향 B — 펜 끝 + 4색 스트로크)을 1024×1024 PNG로 렌더.
// Light / Dark / Tinted 세 가지 variant를 모두 생성하고 AppIcon.appiconset 갱신.
//
// 실행:
//   swift /Users/hg/Desktop/Lumark/scripts/generate-app-icon.swift
//

import SwiftUI
import AppKit

// MARK: - OKLCh → sRGB

func oklchSRGB(L: Double, C: Double, h: Double) -> (Double, Double, Double) {
    let hRad = h * .pi / 180
    let a = C * cos(hRad)
    let b = C * sin(hRad)
    let l_ = L + 0.3963377774 * a + 0.2158037573 * b
    let m_ = L - 0.1055613458 * a - 0.0638541728 * b
    let s_ = L - 0.0894841775 * a - 1.2914855480 * b
    let lc = l_*l_*l_, mc = m_*m_*m_, sc = s_*s_*s_
    let lr =  4.0767416621*lc - 3.3077115913*mc + 0.2309699292*sc
    let lg = -1.2684380046*lc + 2.6097574011*mc - 0.3413193965*sc
    let lb = -0.0041960863*lc - 0.7034186147*mc + 1.7076147010*sc
    func gamma(_ c: Double) -> Double {
        let cc = max(0, min(1, c))
        return cc >= 0.0031308 ? 1.055 * pow(cc, 1.0/2.4) - 0.055 : 12.92 * cc
    }
    return (gamma(lr), gamma(lg), gamma(lb))
}

extension Color {
    init(oklchL L: Double, C: Double, h: Double, alpha: Double = 1) {
        let (r, g, b) = oklchSRGB(L: L, C: C, h: h)
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Chisel shapes

struct ChiselTip: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: .init(x: 0, y: 0))
        p.addLine(to: .init(x: 84.0/122 * w, y: 0))
        p.addLine(to: .init(x: w, y: h))
        p.addLine(to: .init(x: 40.0/122 * w, y: h))
        p.closeSubpath()
        return p
    }
}

struct ChiselTipHighlight: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: .init(x: 0, y: 0))
        p.addLine(to: .init(x: w, y: 0))
        p.addLine(to: .init(x: 72.0/84 * w, y: h))
        p.addLine(to: .init(x: 8.0/84 * w, y: h))
        p.closeSubpath()
        return p
    }
}

// MARK: - Variant

enum IconVariant {
    case light
    case dark
    case tinted
}

// MARK: - 아이콘 뷰

struct LumarkIconB: View {
    var size: CGFloat
    var variant: IconVariant = .light
    /// 펜+스트로크 아트워크를 키워 아이콘을 더 꽉 채우는 배율.
    var contentScale: CGFloat = 1.0
    /// 배율 후 중심 보정 (1024 기준 px 단위).
    var contentShift: CGSize = .zero
    private var s: CGFloat { size / 1024 }

    var body: some View {
        ZStack {
            background
            sheen
            artwork
                .scaleEffect(contentScale, anchor: .center)
                .offset(x: contentShift.width * s, y: contentShift.height * s)
        }
        .frame(width: size, height: size)
        .clipped()
    }

    /// 펜 + 4색 스트로크 묶음. 배율/위치는 호출부에서 조정.
    private var artwork: some View {
        ZStack {
            strokes
                .offset(x: 228 * s - 512 * s, y: 540 * s - 512 * s)
                .rotationEffect(.degrees(-22), anchor: .topLeading)
            penBody
                .offset(x: 256 * s - 512 * s, y: 564 * s - 512 * s)
                .rotationEffect(.degrees(-22), anchor: .topLeading)
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .light:
            LinearGradient(
                stops: [
                    .init(color: Color(oklchL: 0.46, C: 0.062, h: 60), location: 0.0),
                    .init(color: Color(oklchL: 0.40, C: 0.058, h: 56), location: 0.55),
                    .init(color: Color(oklchL: 0.30, C: 0.050, h: 54), location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom
            )
        case .dark:
            LinearGradient(
                stops: [
                    .init(color: Color(oklchL: 0.24, C: 0.040, h: 56), location: 0.0),
                    .init(color: Color(oklchL: 0.18, C: 0.035, h: 54), location: 0.55),
                    .init(color: Color(oklchL: 0.12, C: 0.028, h: 52), location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom
            )
        case .tinted:
            // Tinted icon: Apple 가이드 — 검정 배경 + 흰색 컨텐츠. 시스템이 자동 tint.
            Color.black
        }
    }

    @ViewBuilder
    private var sheen: some View {
        if variant != .tinted {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 1, green: 240/255, blue: 210/255).opacity(variant == .dark ? 0.06 : 0.10), location: 0.0),
                    .init(color: Color(red: 1, green: 240/255, blue: 210/255).opacity(0), location: 0.60),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    private var strokes: some View {
        ZStack(alignment: .topLeading) {
            stroke(yellowColor,  x: 0,   y: 0,   w: 600)
            stroke(orangeColor,  x: 40,  y: 78,  w: 520)
            stroke(pinkColor,    x: 80,  y: 156, w: 440)
            stroke(blueColor,    x: 120, y: 234, w: 360)
        }
        .opacity(variant == .tinted ? 1.0 : 0.95)
    }

    private func stroke(_ color: Color, x: CGFloat, y: CGFloat, w: CGFloat) -> some View {
        Capsule()
            .fill(color)
            .frame(width: w * s, height: 42 * s)
            .offset(x: x * s, y: y * s)
    }

    // Variant별 색
    private var yellowColor: Color {
        switch variant {
        case .light:  return Color(oklchL: 0.80, C: 0.180, h: 88)
        case .dark:   return Color(oklchL: 0.72, C: 0.140, h: 88)
        case .tinted: return Color.white.opacity(0.95)
        }
    }
    private var orangeColor: Color {
        switch variant {
        case .light:  return Color(oklchL: 0.72, C: 0.180, h: 50)
        case .dark:   return Color(oklchL: 0.64, C: 0.140, h: 50)
        case .tinted: return Color.white.opacity(0.78)
        }
    }
    private var pinkColor: Color {
        switch variant {
        case .light:  return Color(oklchL: 0.72, C: 0.175, h: 0)
        case .dark:   return Color(oklchL: 0.64, C: 0.135, h: 0)
        case .tinted: return Color.white.opacity(0.62)
        }
    }
    private var blueColor: Color {
        switch variant {
        case .light:  return Color(oklchL: 0.70, C: 0.130, h: 235)
        case .dark:   return Color(oklchL: 0.60, C: 0.095, h: 235)
        case .tinted: return Color.white.opacity(0.46)
        }
    }

    private var penBody: some View {
        ZStack(alignment: .topLeading) {
            // 그림자 (tinted엔 생략)
            if variant != .tinted {
                RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                    .fill(Color.black.opacity(variant == .dark ? 0.28 : 0.18))
                    .frame(width: 92 * s, height: 320 * s)
                    .offset(x: (-46 + 8) * s, y: (-28 + 6) * s)
            }

            // 바디
            RoundedRectangle(cornerRadius: 12 * s, style: .continuous)
                .fill(penBodyColor)
                .frame(width: 84 * s, height: 280 * s)
                .offset(x: -42 * s, y: -260 * s)

            // 황동 링 (tinted엔 흰색)
            Rectangle()
                .fill(brassColor)
                .frame(width: 84 * s, height: 14 * s)
                .offset(x: -42 * s, y: -30 * s)

            // chisel tip
            ChiselTip()
                .fill(tipColor)
                .frame(width: 122 * s, height: 72 * s)
                .offset(x: -42 * s, y: -16 * s)

            // tip highlight
            ChiselTipHighlight()
                .fill(Color.white.opacity(variant == .tinted ? 0 : 0.20))
                .frame(width: 84 * s, height: 14 * s)
                .offset(x: -42 * s, y: -16 * s)
        }
    }

    private var penBodyColor: Color {
        switch variant {
        case .light:  return Color(oklchL: 0.94, C: 0.018, h: 82)
        case .dark:   return Color(oklchL: 0.78, C: 0.016, h: 82)
        case .tinted: return Color.white
        }
    }
    private var brassColor: Color {
        switch variant {
        case .light:  return Color(oklchL: 0.70, C: 0.10, h: 78)
        case .dark:   return Color(oklchL: 0.58, C: 0.085, h: 78)
        case .tinted: return Color.white.opacity(0.7)
        }
    }
    private var tipColor: Color {
        switch variant {
        case .light:  return Color(oklchL: 0.30, C: 0.04, h: 54)
        case .dark:   return Color(oklchL: 0.18, C: 0.030, h: 54)
        case .tinted: return Color.white.opacity(0.85)
        }
    }
}

// MARK: - 렌더 헬퍼

func renderPNG(_ view: some View) -> Data? {
    MainActor.assumeIsolated {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:])
        else { return nil }
        return data
    }
}

// MARK: - 메인

let outDir = "/Users/hg/Desktop/Lumark/Lumark/Assets.xcassets/AppIcon.appiconset"

struct Variant {
    let kind: IconVariant
    let filename: String
}

let variants: [Variant] = [
    .init(kind: .light,  filename: "AppIcon-1024.png"),
    .init(kind: .dark,   filename: "AppIcon-1024-dark.png"),
    .init(kind: .tinted, filename: "AppIcon-1024-tinted.png"),
]

// 아트워크를 키워 아이콘을 꽉 채움. 렌더 결과 보고 조정.
let fillScale: CGFloat = 1.35
let fillShift = CGSize(width: 28, height: 18)

for v in variants {
    guard let png = renderPNG(LumarkIconB(
        size: 1024,
        variant: v.kind,
        contentScale: fillScale,
        contentShift: fillShift
    )) else {
        print("error: render failed for \(v.kind)")
        exit(1)
    }
    let path = "\(outDir)/\(v.filename)"
    do {
        try png.write(to: URL(fileURLWithPath: path), options: .atomic)
        print("✓ \(v.filename) (\(png.count) bytes)")
    } catch {
        print("error: write \(v.filename) — \(error)")
        exit(1)
    }
}

// MARK: - Contents.json 갱신

let contentsPath = "\(outDir)/Contents.json"
let contentsURL = URL(fileURLWithPath: contentsPath)

struct ImageEntry: Codable {
    var appearances: [Appearance]?
    var filename: String?
    var idiom: String
    var platform: String?
    var scale: String?
    var size: String
}
struct Appearance: Codable { var appearance: String; var value: String }
struct AppIconJSON: Codable {
    var images: [ImageEntry]
    var info: Info
}
struct Info: Codable { var author: String; var version: Int }

let data = try Data(contentsOf: contentsURL)
var json = try JSONDecoder().decode(AppIconJSON.self, from: data)

for i in json.images.indices {
    let e = json.images[i]
    guard e.idiom == "universal", (e.platform ?? "") == "ios" else { continue }
    if let appearances = e.appearances {
        if appearances.contains(where: { $0.value == "dark" }) {
            json.images[i].filename = "AppIcon-1024-dark.png"
        } else if appearances.contains(where: { $0.value == "tinted" }) {
            json.images[i].filename = "AppIcon-1024-tinted.png"
        }
    } else {
        json.images[i].filename = "AppIcon-1024.png"
    }
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
let updated = try encoder.encode(json)
try updated.write(to: contentsURL)
print("✓ updated Contents.json — 3 variants attached")
