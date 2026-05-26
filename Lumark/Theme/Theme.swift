//
//  Theme.swift
//  Lumark
//
//  디자인 토큰 — Lumark_design/Design System.html의 oklch 값을 그대로 옮김.
//  oklch는 UIColor가 네이티브 지원하지 않으므로 런타임에 sRGB로 변환한다.
//  Light/Dark 양쪽 정의 → UIColor(dynamicProvider:)로 자동 전환.
//

import SwiftUI
import UIKit

// MARK: - OKLCh → sRGB 변환
//
// OKLab/OKLCh: Björn Ottosson 2020. https://bottosson.github.io/posts/oklab/
// 변환 경로: OKLCh → OKLab → linear sRGB → sRGB
//
enum OKLCh {
    /// L: 0~1 (lightness), C: 0~0.4 정도 (chroma), h: 0~360 (hue degree)
    static func toSRGB(L: Double, C: Double, h: Double) -> (r: Double, g: Double, b: Double) {
        // 1) OKLCh → OKLab
        let hRad = h * .pi / 180
        let a = C * cos(hRad)
        let b = C * sin(hRad)

        // 2) OKLab → linear sRGB
        let l_ = L + 0.3963377774 * a + 0.2158037573 * b
        let m_ = L - 0.1055613458 * a - 0.0638541728 * b
        let s_ = L - 0.0894841775 * a - 1.2914855480 * b

        let lc = l_ * l_ * l_
        let mc = m_ * m_ * m_
        let sc = s_ * s_ * s_

        let lr =  4.0767416621 * lc - 3.3077115913 * mc + 0.2309699292 * sc
        let lg = -1.2684380046 * lc + 2.6097574011 * mc - 0.3413193965 * sc
        let lb = -0.0041960863 * lc - 0.7034186147 * mc + 1.7076147010 * sc

        // 3) linear sRGB → sRGB (gamma)
        func gamma(_ c: Double) -> Double {
            let cc = max(0, min(1, c))
            return cc >= 0.0031308
                ? 1.055 * pow(cc, 1.0 / 2.4) - 0.055
                : 12.92 * cc
        }

        return (gamma(lr), gamma(lg), gamma(lb))
    }
}

extension UIColor {
    /// oklch(L C h) → UIColor (sRGB)
    convenience init(oklchL L: Double, C: Double, h: Double, alpha: Double = 1) {
        let (r, g, b) = OKLCh.toSRGB(L: L, C: C, h: h)
        self.init(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(alpha))
    }

    /// Light/Dark 양쪽 정의를 dynamic UIColor로 래핑
    static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        }
    }
}

extension Color {
    init(oklchL L: Double, C: Double, h: Double, alpha: Double = 1) {
        self.init(uiColor: UIColor(oklchL: L, C: C, h: h, alpha: alpha))
    }
}

// MARK: - 디자인 토큰

/// 앱 전역 색상 팔레트. Design System.html과 1:1 대응.
enum Palette {
    // 베이스 (light → dark)
    static let brown      = dyn(l: (0.43, 0.060, 58),    d: (0.74, 0.075, 62))
    static let brown2     = dyn(l: (0.37, 0.055, 55),    d: (0.66, 0.072, 60))
    static let cream      = dyn(l: (0.962, 0.018, 82),   d: (0.175, 0.014, 55))
    static let surface    = dyn(l: (0.985, 0.010, 82),   d: (0.215, 0.014, 56))
    static let surface2   = dyn(l: (0.945, 0.020, 82),   d: (0.255, 0.016, 56))
    static let ink        = dyn(l: (0.255, 0.026, 50),   d: (0.925, 0.014, 80))
    static let ink2       = dyn(l: (0.34, 0.022, 50),    d: (0.84, 0.018, 75))
    static let subtle     = dyn(l: (0.555, 0.018, 52),   d: (0.66, 0.015, 60))
    static let muted      = dyn(l: (0.72, 0.015, 60),    d: (0.50, 0.013, 60))
    static let divider    = dyn(l: (0.895, 0.014, 70),   d: (0.28, 0.013, 55))
    static let hairline   = dyn(l: (0.84, 0.014, 65),    d: (0.34, 0.014, 55))
    static let brass      = dyn(l: (0.68, 0.10, 75),     d: (0.78, 0.09, 78))

    // 형광펜 4색 — Hue는 light/dark 공통, bg/edge만 모드별로 다름
    enum Highlight {
        static let yellow     = uic(l: 0.78, c: 0.180, h: 88)
        static let orange     = uic(l: 0.72, c: 0.180, h: 50)
        static let pink       = uic(l: 0.72, c: 0.175, h: 0)
        static let blue       = uic(l: 0.70, c: 0.130, h: 235)

        static let yellowBG   = dyn(l: (0.955, 0.085, 92),  d: (0.36, 0.090, 88))
        static let yellowEdge = dyn(l: (0.84, 0.140, 90),   d: (0.52, 0.130, 88))
        static let orangeBG   = dyn(l: (0.935, 0.075, 60),  d: (0.36, 0.095, 50))
        static let orangeEdge = dyn(l: (0.80, 0.140, 55),   d: (0.52, 0.135, 50))
        static let pinkBG     = dyn(l: (0.935, 0.060, 0),   d: (0.36, 0.095, 0))
        static let pinkEdge   = dyn(l: (0.82, 0.115, 0),    d: (0.52, 0.130, 0))
        static let blueBG     = dyn(l: (0.935, 0.045, 235), d: (0.34, 0.075, 235))
        static let blueEdge   = dyn(l: (0.81, 0.085, 235),  d: (0.50, 0.110, 235))
    }

    // MARK: helpers
    private static func uic(l: Double, c: Double, h: Double) -> Color {
        Color(oklchL: l, C: c, h: h)
    }

    private static func dyn(l: (Double, Double, Double), d: (Double, Double, Double)) -> Color {
        let lightUI = UIColor(oklchL: l.0, C: l.1, h: l.2)
        let darkUI  = UIColor(oklchL: d.0, C: d.1, h: d.2)
        return Color(uiColor: .dynamic(light: lightUI, dark: darkUI))
    }
}

// MARK: - 타이포그래피

/// 디자인 시스템 폰트. v0.1은 시스템 폰트 fallback 사용 (커스텀 폰트 번들링은 v0.2).
/// 디자인 의도:
///   - display: Nanum Myeongjo (브랜드/제목) → serif fallback
///   - body:    Noto Sans KR → system sans
///   - mono:    JetBrains Mono → monospaced
enum Typo {
    // Display (Nanum Myeongjo 800)
    static let display  = Font.system(size: 44, weight: .heavy, design: .serif)
    static let h1       = Font.system(size: 30, weight: .heavy, design: .serif)
    static let h2       = Font.system(size: 22, weight: .bold, design: .serif)
    static let brand    = Font.system(size: 30, weight: .heavy, design: .serif)
    static let brandSm  = Font.system(size: 26, weight: .heavy, design: .serif)

    // Body (Noto Sans KR)
    static let lede     = Font.system(size: 17, weight: .regular)
    static let body     = Font.system(size: 15, weight: .regular)
    static let bodyMd   = Font.system(size: 15, weight: .medium)
    static let bodySm   = Font.system(size: 13, weight: .regular)
    static let caption  = Font.system(size: 12, weight: .regular)
    static let eyebrow  = Font.system(size: 11, weight: .semibold).width(.expanded)

    // Mono (JetBrains Mono)
    static let mono     = Font.system(size: 12.5, weight: .regular, design: .monospaced)
    static let monoSm   = Font.system(size: 11, weight: .regular, design: .monospaced)
}

// MARK: - 스페이싱 / 라운드 / 그림자

enum Space {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 24
    static let s6: CGFloat = 32
    static let s7: CGFloat = 48
}

enum Radius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 12
    static let lg: CGFloat = 20
}

enum Shadow {
    // Design System.html --shadow-1
    static let card = ShadowStyle(
        color: Color.black.opacity(0.10),
        radius: 18,
        x: 0,
        y: 6
    )

    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

extension View {
    func cardShadow() -> some View {
        self.shadow(
            color: Shadow.card.color,
            radius: Shadow.card.radius,
            x: Shadow.card.x,
            y: Shadow.card.y
        )
    }
}
