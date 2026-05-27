//
//  SettingsView.swift
//  Lumark
//
//  spec §2: 활성 색 매핑(라벨/활성) + 구조 인식 룰 안내(읽기 전용) + 앱 정보.
//  v0.1은 노랑/주황만 노출 (분홍/파랑은 v0.2+).
//  iOS 표준 Form 패턴을 디자인 토큰으로 살짝 다듬음.
//

import SwiftUI

struct SettingsView: View {
    @State private var store = ColorRuleStore.shared
    @State private var exportPrefs = ExportPreferences.shared
    @State private var debugPrefs = DebugPreferences.shared
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedColor: ColorCategory?

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.cream.ignoresSafeArea()

                Form {
                    colorMappingSection
                    exportSection
                    structureRuleSection
                    debugSection
                    aboutSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { dismiss() }
                        .foregroundStyle(Palette.brown)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - 색상 매핑

    private var colorMappingSection: some View {
        Section {
            ForEach(ColorCategory.activeInV01) { color in
                colorRow(color)
            }

            Button {
                store.resetToDefaults()
            } label: {
                Text("기본값으로 되돌리기")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.brown)
            }
        } header: {
            sectionHeader("색상 매핑", subtitle: "각 형광펜 색이 무엇을 뜻하는지 정해요")
        }
        .listRowBackground(Palette.surface)
    }

    @ViewBuilder
    private func colorRow(_ color: ColorCategory) -> some View {
        let rule = store.rule(for: color) ?? ColorRule.defaults.first(where: { $0.color == color })!
        let labelBinding = Binding(
            get: { store.rule(for: color)?.label ?? "" },
            set: { store.setLabel($0, for: color) }
        )
        let enabledBinding = Binding(
            get: { store.rule(for: color)?.isEnabled ?? false },
            set: { store.setEnabled($0, for: color) }
        )

        HStack(spacing: Space.s3) {
            Circle()
                .fill(color.swatch)
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(Palette.hairline, lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 2) {
                Text(defaultName(color))
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Palette.ink)

                TextField(
                    placeholder(for: color),
                    text: labelBinding
                )
                .font(.system(size: 13))
                .foregroundStyle(Palette.ink2)
                .focused($focusedColor, equals: color)
                .submitLabel(.done)
                .onSubmit { focusedColor = nil }
            }

            Spacer()

            Toggle("", isOn: enabledBinding)
                .labelsHidden()
                .tint(Palette.brown)
        }
        .padding(.vertical, 4)
        .opacity(rule.isEnabled ? 1.0 : 0.55)
    }

    private func defaultName(_ c: ColorCategory) -> String {
        switch c {
        case .yellow: return "노랑"
        case .orange: return "주황"
        case .pink:   return "분홍"
        case .blue:   return "파랑"
        }
    }

    private func placeholder(for c: ColorCategory) -> String {
        let d = c.defaultLabel
        return d.isEmpty ? "라벨 (예: 보충, 주의)" : "라벨 (기본: \(d))"
    }

    // MARK: - 마크다운 출력 옵션

    private var exportSection: some View {
        Section {
            Picker("문법", selection: Binding(
                get: { exportPrefs.dialect },
                set: { exportPrefs.dialect = $0 }
            )) {
                ForEach(MarkdownDialect.allCases, id: \.rawValue) { d in
                    Text(d.description).tag(d)
                }
            }
            .font(.system(size: 14))

            Toggle(isOn: Binding(
                get: { exportPrefs.includePageMap },
                set: { exportPrefs.includePageMap = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("페이지 매핑 표 포함")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.ink)
                    Text("어느 페이지에 어느 섹션이 있었는지 표로 정리")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.subtle)
                }
            }
            .tint(Palette.brown)
        } header: {
            sectionHeader("마크다운 출력", subtitle: "복사·내보내기 결과의 형태")
        }
        .listRowBackground(Palette.surface)
    }

    // MARK: - 구조 인식 룰 안내

    private var structureRuleSection: some View {
        Section {
            ruleRow(
                badge: "🟠",
                title: "주황 = 섹션 제목",
                desc: "주황으로 표시된 텍스트가 새 섹션의 제목이 됩니다."
            )
            ruleRow(
                badge: "🟡",
                title: "노랑 = 글머리표",
                desc: "노랑으로 표시된 텍스트는 섹션 아래 글머리표로 정리됩니다."
            )
        } header: {
            sectionHeader("구조 인식 룰", subtitle: "현재 버전에서는 수정할 수 없어요")
        }
        .listRowBackground(Palette.surface)
    }

    private func ruleRow(badge: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: Space.s3) {
            Text(badge)
                .font(.system(size: 18))
                .frame(width: 32, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(desc)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.subtle)
                    .lineSpacing(2)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 디버그 (검출 시각화)

    private var debugSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { debugPrefs.showDetectionOverlay },
                set: { debugPrefs.showDetectionOverlay = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("검출 영역 표시")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.ink)
                    Text("결과 화면 \"원본\" 탭에서 형광펜 검출 박스를 페이지 위에 덧그려요. HSV 임계값 튜닝용.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.subtle)
                }
            }
            .tint(Palette.brown)
        } header: {
            sectionHeader("디버그", subtitle: "검증·튜닝용 옵션")
        }
        .listRowBackground(Palette.surface)
    }

    // MARK: - 앱 정보

    private var aboutSection: some View {
        Section {
            infoRow(label: "버전", value: appVersion)
            infoRow(label: "Lumark", value: "v0.1 MVP")

            Button {
                // 안내 시트 다시 보기 — 플래그 리셋 후 dismiss하면 HomeView가 첫 실행 처리
                UserDefaults.standard.set(false, forKey: "lumark.onboarded")
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.brass)
                    Text("처음 안내 다시 보기")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.ink2)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                }
            }
        } header: {
            sectionHeader("정보", subtitle: nil)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lumark — 간호학과 학생용 형광펜 자동 분류 노트")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.subtle)
                Text("Apple Vision Framework로 오프라인 OCR. 데이터는 기기에만 저장됩니다.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.subtle)
            }
            .padding(.top, 8)
        }
        .listRowBackground(Palette.surface)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Palette.ink2)
            Spacer()
            Text(value)
                .font(Typo.mono)
                .foregroundStyle(Palette.subtle)
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    // MARK: - section header

    private func sectionHeader(_ title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Palette.brass)
                .textCase(nil)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.subtle)
                    .textCase(nil)
            }
        }
        .padding(.bottom, 4)
    }
}

#Preview {
    SettingsView()
}
