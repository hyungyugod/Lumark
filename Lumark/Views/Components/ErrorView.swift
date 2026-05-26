//
//  ErrorView.swift
//  Lumark
//
//  spec §8 매트릭스의 표준 표현.
//  사용처:
//    - 전체 화면 ErrorView (예: ProcessingView가 실패했을 때 그 자리 교체)
//    - 인라인 ErrorBanner (예: 부분 성공 상단 배너)
//    - .errorAlert(error:onAction:) modifier (간단한 alert 폴백)
//

import SwiftUI

// MARK: - 풀스크린 / 카드형 ErrorView

struct LumarkErrorView: View {
    let error: LumarkError
    let onAction: (ErrorAction) -> Void

    var body: some View {
        VStack(spacing: Space.s4) {
            // 아이콘
            ZStack {
                Circle()
                    .fill(badgeFill)
                    .frame(width: 64, height: 64)
                Image(systemName: iconName)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(badgeIconColor)
            }

            VStack(spacing: 6) {
                Text(error.userTitle)
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)

                Text(error.userMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.subtle)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(maxWidth: 280)
            }

            // 디버그 코드 (작게)
            Text(error.debugCode)
                .font(Typo.monoSm)
                .foregroundStyle(Palette.muted)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Palette.surface2)
                )

            Spacer().frame(height: Space.s4)

            // 액션 버튼들
            VStack(spacing: 8) {
                ForEach(Array(error.defaultActions.enumerated()), id: \.offset) { _, action in
                    Button {
                        onAction(action)
                    } label: {
                        Text(action.label)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(action.isPrimary ? Palette.cream : Palette.ink2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                    .fill(action.isPrimary ? Palette.brown : Palette.surface2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                    .strokeBorder(action.isPrimary ? Color.clear : Palette.hairline, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Space.s5)
            .frame(maxWidth: 360)
        }
        .padding(.vertical, Space.s7)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.cream)
    }

    // MARK: - severity-aware 시각

    private var iconName: String {
        switch error {
        case .noHighlightsDetected, .detectionEmpty, .ocrAllEmpty:
            return "magnifyingglass"
        case .pdfCorrupted, .unsupportedFormat:
            return "doc.questionmark"
        case .inputTooLarge:
            return "doc.text.magnifyingglass"
        case .allPagesBlank:
            return "doc.text"
        case .cancelled:
            return "xmark"
        case .outOfMemory, .diskFull:
            return "exclamationmark.triangle"
        case .cameraPermissionDenied:
            return "camera.circle"
        case .photosPermissionDenied:
            return "photo.circle"
        case .appGroupAccessFailed:
            return "exclamationmark.shield"
        case .partialSuccess:
            return "checkmark.circle"
        case .wrapped:
            return "exclamationmark.circle"
        }
    }

    private var badgeFill: Color {
        switch error.severity {
        case .error:   return Palette.Highlight.pinkBG
        case .warning: return Palette.Highlight.yellowBG
        case .info:    return Palette.surface2
        }
    }

    private var badgeIconColor: Color {
        switch error.severity {
        case .error:   return Palette.Highlight.pink
        case .warning: return Palette.brass
        case .info:    return Palette.ink2
        }
    }
}

// MARK: - 인라인 배너 (부분 성공 / 경고용)

struct ErrorBanner: View {
    let error: LumarkError
    let onAction: ((ErrorAction) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: Space.s3) {
            Image(systemName: bannerIcon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
                .background(Circle().fill(accent.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(error.userTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(error.userMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.subtle)
                    .lineSpacing(1.5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let onAction, let primary = error.defaultActions.first(where: { $0.isPrimary }) {
                Button(primary.label) { onAction(primary) }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(accent.opacity(0.3), lineWidth: 1)
        )
    }

    private var accent: Color {
        switch error.severity {
        case .error:   return Palette.Highlight.pink
        case .warning: return Palette.brass
        case .info:    return Palette.subtle
        }
    }

    private var bannerIcon: String {
        switch error.severity {
        case .error:   return "exclamationmark.triangle.fill"
        case .warning: return "info.circle.fill"
        case .info:    return "info.circle"
        }
    }
}

// MARK: - .errorAlert(error:onAction:) modifier (간단 폴백)

extension View {
    /// 작은 에러는 alert로. ErrorBinding이 nil이 아닐 때 표시.
    func errorAlert(
        error: Binding<LumarkError?>,
        onAction: ((ErrorAction) -> Void)? = nil
    ) -> some View {
        let isPresented = Binding(
            get: { error.wrappedValue != nil },
            set: { if !$0 { error.wrappedValue = nil } }
        )
        return self.alert(
            error.wrappedValue?.userTitle ?? "",
            isPresented: isPresented,
            presenting: error.wrappedValue
        ) { err in
            ForEach(Array(err.defaultActions.enumerated()), id: \.offset) { _, action in
                Button(
                    action.label,
                    role: action == .cancel ? .cancel : nil
                ) {
                    onAction?(action)
                    error.wrappedValue = nil
                }
            }
        } message: { err in
            Text(err.userMessage)
        }
    }
}

#Preview("Error — no highlights") {
    LumarkErrorView(error: .noHighlightsDetected) { _ in }
}

#Preview("Warning — input too large") {
    LumarkErrorView(error: .inputTooLarge(sizeMB: 62, pages: 120)) { _ in }
}

#Preview("Permission") {
    LumarkErrorView(error: .cameraPermissionDenied) { _ in }
}

#Preview("Banner — partial success") {
    VStack {
        ErrorBanner(error: .partialSuccess(succeeded: 10, total: 12)) { _ in }
        Spacer()
    }
    .padding()
    .background(Palette.cream)
}
