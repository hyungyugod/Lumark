//
//  ResultView.swift
//  Lumark
//
//  변환 결과 화면 — 디자인: Lumark_design/ResultView.html
//
//  구성:
//    - 커스텀 nav (back / title / more)
//    - 탭 토글 (마크다운 / 원본 PDF) — underline
//    - 4색 필터 칩 행 (가로 스크롤)
//    - 본문 (MarkdownBodyView OR PDFFauxView)
//    - 하단 액션 바 (복사 / 공유 / PDF 내보내기)
//

import SwiftUI
import SwiftData
import UIKit

struct ResultView: View {
    let note: Note
    var onClose: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Query private var allNotes: [Note]
    @State private var store = ColorRuleStore.shared

    enum Tab: String { case markdown, pdf }

    @State private var tab: Tab = .markdown
    /// 색별 필터 ON/OFF. 초기값은 ColorRuleStore.isEnabled. 이후 사용자가
    /// 결과 화면에서 끄고 켤 수 있으므로 화면 로컬 상태로 분리한다.
    @State private var chips: [ColorCategory: Bool] = Self.initialChips()
    @State private var showingMore = false

    /// ColorRuleStore.shared의 현재 활성 상태 스냅샷.
    /// init 시점에 한 번만 평가됨 — 사용자가 설정에서 활성 토글하더라도
    /// 결과 화면 안의 chips는 화면 내 토글로만 변함 (의도된 분리).
    private static func initialChips() -> [ColorCategory: Bool] {
        Dictionary(uniqueKeysWithValues: ColorCategory.allCases.map {
            ($0, ColorRuleStore.shared.isEnabled($0))
        })
    }

    // CRUD
    @State private var showingRenameSheet = false
    @State private var showingDeleteConfirm = false
    @State private var editingTitle: String = ""

    // 액션 상태
    @State private var toastMessage: String?
    @State private var shareItems: [Any]?
    @State private var isPreparingExport = false
    @State private var activeError: LumarkError?

    /// 이 Note가 SwiftData 컨테이너에 이미 영속화돼있는가.
    /// 영속화 안 됐으면 저장 버튼 노출.
    private var isPersisted: Bool {
        allNotes.contains { $0.id == note.id }
    }

    var body: some View {
        let document = MarkdownDocument.from(note)

        ZStack(alignment: .bottom) {
            Palette.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                tabBar
                chipBar
                Divider().overlay(Palette.divider)

                ScrollView {
                    VStack(spacing: 0) {
                        switch tab {
                        case .markdown:
                            MarkdownBodyView(
                                document: document,
                                chips: chips,
                                pinkLabel: store.displayLabel(for: .pink),
                                blueLabel: store.displayLabel(for: .blue)
                            )
                        case .pdf:
                            PDFFauxView(document: document, chips: chips)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                    .padding(.bottom, 120) // action bar 공간
                }
            }

            ResultActionBar(
                onCopy: copy,
                onShare: share,
                onExportPDF: exportPDF
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .navigationBarHidden(true)
        .confirmationDialog("더보기", isPresented: $showingMore, titleVisibility: .hidden) {
            if !isPersisted {
                Button("저장") { save() }
            } else {
                Button(note.isFavorite ? "즐겨찾기 해제" : "즐겨찾기 추가") {
                    toggleFavorite()
                }
            }
            Button("이름 변경") {
                editingTitle = note.title
                showingRenameSheet = true
            }
            if isPersisted {
                Button("삭제", role: .destructive) {
                    showingDeleteConfirm = true
                }
            }
            Button("취소", role: .cancel) {}
        }
        .alert("이 노트를 삭제할까요?", isPresented: $showingDeleteConfirm) {
            Button("삭제", role: .destructive) { delete() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("\(note.title) — 되돌릴 수 없어요.")
        }
        .sheet(isPresented: $showingRenameSheet) {
            NoteRenameSheet(
                title: $editingTitle,
                onSave: {
                    rename(to: editingTitle)
                    showingRenameSheet = false
                },
                onCancel: { showingRenameSheet = false }
            )
            .presentationDetents([.height(220)])
        }
        .overlay(alignment: .top) {
            if let msg = toastMessage {
                ToastView(text: msg)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay {
            if isPreparingExport {
                ZStack {
                    Color.black.opacity(0.18).ignoresSafeArea()
                    ProgressView("PDF 만드는 중…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { shareItems != nil },
            set: { if !$0 { shareItems = nil } }
        )) {
            if let items = shareItems {
                ShareSheet(items: items)
                    .presentationDetents([.medium, .large])
            }
        }
        .errorAlert(error: $activeError)
    }

    // MARK: - Nav

    private var navBar: some View {
        HStack(spacing: 0) {
            Button {
                onClose?()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.brown)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(note.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)

            Spacer()

            if !isPersisted {
                Button {
                    save()
                } label: {
                    Text("저장")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.brown)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(
                            Capsule().fill(Palette.Highlight.yellowBG)
                        )
                        .overlay(
                            Capsule().strokeBorder(Palette.Highlight.yellowEdge, lineWidth: 1)
                        )
                }
                .padding(.trailing, 4)
            }

            Button {
                showingMore = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.brown)
                    .frame(width: 44, height: 44)
            }
        }
        .frame(height: 52)
        .padding(.horizontal, 6)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Palette.divider.opacity(0.6))
                .frame(height: 1)
        }
    }

    // MARK: - Tab

    private var tabBar: some View {
        HStack(spacing: 28) {
            tabButton(.markdown, label: "마크다운")
            tabButton(.pdf, label: "원본 PDF")
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Palette.divider)
                .frame(height: 1)
        }
    }

    private func tabButton(_ t: Tab, label: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { tab = t }
        } label: {
            VStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 14.5, weight: tab == t ? .semibold : .medium))
                    .foregroundStyle(tab == t ? Palette.ink : Palette.subtle)
                    .padding(.top, 12)
                    .padding(.bottom, 14)

                Rectangle()
                    .fill(tab == t ? Palette.brown : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chips

    private var chipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ColorCategory.allCases) { color in
                    ColorFilterChip(
                        color: color,
                        label: chipLabel(color),
                        isOn: chips[color] ?? false
                    ) {
                        chips[color] = !(chips[color] ?? false)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    /// 칩 라벨: "색 (사용자라벨)" — 사용자가 라벨을 비웠으면 색 이름만.
    private func chipLabel(_ c: ColorCategory) -> String {
        let colorName: String = switch c {
        case .yellow: "노랑"
        case .orange: "주황"
        case .pink:   "분홍"
        case .blue:   "파랑"
        }
        let userLabel = store.rule(for: c)?.label.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return userLabel.isEmpty ? colorName : "\(colorName) (\(userLabel))"
    }

    // MARK: - Actions

    private var currentDoc: MarkdownDocument {
        MarkdownDocument.from(note)
    }

    /// MainActor → nonisolated 경계를 건너기 위한 라벨/활성 스냅샷.
    /// ColorRuleStore가 사용자 설정의 단일 출처.
    private var labelSnapshot: ColorRuleSnapshot {
        store.currentSnapshot()
    }

    private func copy() {
        let prefs = ExportPreferences.shared
        let md = MarkdownExporter.export(
            currentDoc,
            dialect: prefs.dialect,
            labels: labelSnapshot,
            includePageMap: prefs.includePageMap
        )
        UIPasteboard.general.string = md
        showToast("마크다운 복사됨")
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func share() {
        let prefs = ExportPreferences.shared
        let md = MarkdownExporter.export(
            currentDoc,
            dialect: prefs.dialect,
            labels: labelSnapshot,
            includePageMap: prefs.includePageMap
        )
        shareItems = [md]
    }

    private func exportPDF() {
        guard !isPreparingExport else { return }
        isPreparingExport = true
        let doc = currentDoc
        let labels = labelSnapshot
        Task.detached(priority: .userInitiated) {
            do {
                let url = try PDFExporter.export(doc, labels: labels)
                await MainActor.run {
                    self.isPreparingExport = false
                    self.shareItems = [url]
                }
            } catch {
                await MainActor.run {
                    self.isPreparingExport = false
                    self.activeError = .wrapped(code: "PDF-EXPORT", message: error.localizedDescription)
                }
            }
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.easeOut(duration: 0.15)) {
            toastMessage = text
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.15)) {
                    if toastMessage == text { toastMessage = nil }
                }
            }
        }
    }

    // MARK: - CRUD

    private func save() {
        guard !isPersisted else { return }
        // Note + Page + Highlight 그래프 전체 insert.
        // SwiftData는 root 한 번만 insert하면 relationship 따라 다 들어감.
        modelContext.insert(note)
        do {
            try modelContext.save()
            showToast("저장됨")
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            activeError = .wrapped(code: "SAVE", message: "저장 실패: \(error.localizedDescription)")
        }
    }

    private func rename(to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != note.title else { return }
        note.title = trimmed
        if isPersisted {
            try? modelContext.save()
        }
        showToast("이름 변경됨")
    }

    private func toggleFavorite() {
        guard isPersisted else { return }
        note.isFavorite.toggle()
        try? modelContext.save()
        showToast(note.isFavorite ? "즐겨찾기 추가됨" : "즐겨찾기 해제됨")
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func delete() {
        guard isPersisted else { return }
        modelContext.delete(note)
        do {
            try modelContext.save()
            onClose?()
        } catch {
            activeError = .wrapped(code: "DELETE", message: "삭제 실패: \(error.localizedDescription)")
        }
    }
}

// MARK: - 보조 컴포넌트

private struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Palette.cream)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(Palette.ink)
            )
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 6)
    }
}

/// UIActivityViewController 래퍼 — ShareLink가 [Any]를 잘 못 받는 경우 대비.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview("Light") {
    ResultView(note: MockData.antibioticsNote())
        .modelContainer(MockData.previewContainer(withMockNotes: false))
}

#Preview("Dark") {
    ResultView(note: MockData.antibioticsNote())
        .preferredColorScheme(.dark)
        .modelContainer(MockData.previewContainer(withMockNotes: false))
}
