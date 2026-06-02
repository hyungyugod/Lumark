//
//  ResultView.swift
//  Lumark
//
//  변환 결과 화면 — 디자인: Lumark_design/ResultView.html
//
//  구성:
//    - 커스텀 nav (back / title / more)
//    - 탭 토글 (마크다운 / 원본 PDF) — underline
//    - 활성 색 필터 칩 행 (가로 스크롤; v0.1은 노랑/주황)
//    - 본문 (MarkdownBodyView OR PDFFauxView)
//    - 하단 액션 바 (복사 / 공유 / PDF 내보내기)
//

import SwiftUI
import SwiftData
import UIKit

struct ResultView: View {
    let note: Note
    var onClose: (() -> Void)? = nil
    /// 노트가 삭제됐을 때 그 id를 알려줌 (상위에서 캐시 정리용).
    var onDeleted: ((UUID) -> Void)? = nil
    /// 화면 진입 시 1회 보여줄 안내(예: OCR 부분 실패). 토스트로 표시.
    var initialNotice: String? = nil

    @Environment(\.modelContext) private var modelContext
    @Query private var allNotes: [Note]
    @State private var store = ColorRuleStore.shared
    @State private var debugPrefs = DebugPreferences.shared

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
        Dictionary(uniqueKeysWithValues: ColorCategory.activeInV01.map {
            ($0, ColorRuleStore.shared.isEnabled($0))
        })
    }

    // CRUD
    @State private var showingRenameSheet = false
    @State private var showingDeleteConfirm = false
    @State private var editingTitle: String = ""

    // 액션 상태
    @State private var toastMessage: String?
    @State private var didShowNotice = false
    @State private var shareItems: [Any]?
    @State private var isPreparingExport = false
    @State private var activeError: LumarkError?

    // 퀴즈
    @State private var isGeneratingQuiz = false
    @State private var showingStudy = false
    @State private var showingSettings = false
    @State private var showingQuizKindPicker = false

    /// 이 Note가 SwiftData 컨테이너에 이미 영속화돼있는가.
    /// 영속화 안 됐으면 저장 버튼 노출.
    private var isPersisted: Bool {
        allNotes.contains { $0.id == note.id }
    }

    /// 실제 파이프라인이 만들어 imageData가 채워진 페이지가 있는가.
    /// Mock 노트(MockData.antibioticsNote)는 imageData가 비어있어 PDFFauxView로 폴백.
    private var hasRealPageImages: Bool {
        note.pages.contains { !$0.imageData.isEmpty }
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
                                chips: chips
                            )
                        case .pdf:
                            if hasRealPageImages {
                                DetectionOverlayView(
                                    note: note,
                                    showOverlay: debugPrefs.showDetectionOverlay
                                )
                            } else {
                                PDFFauxView(document: document, chips: chips)
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                    .padding(.bottom, quizCostBadge == nil ? 120 : 146) // action bar + quiz credit note 공간
                }
            }

            VStack(spacing: 6) {
                if let cost = quizCostBadge {
                    Text("퀴즈 생성 1회 = \(cost)크레딧")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.subtle)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Palette.surface.opacity(0.92)))
                        .overlay(Capsule().strokeBorder(Palette.divider, lineWidth: 1))
                }

                ResultActionBar(
                    onCopy: copy,
                    onShare: share,
                    onExportPDF: exportPDF,
                    quizSystemImage: note.flashcards.isEmpty ? "sparkles" : "rectangle.stack.fill",
                    quizLabel: note.flashcards.isEmpty ? "퀴즈 만들기" : "퀴즈 보기",
                    quizCost: quizCostBadge,
                    onQuiz: {
                        if note.flashcards.isEmpty { showingQuizKindPicker = true } else { showingStudy = true }
                    }
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .navigationBarHidden(true)
        .onAppear {
            // 부분 실패 등 1회성 안내 — 진입 시 한 번, 조금 길게 노출.
            if let notice = initialNotice, !didShowNotice {
                didShowNotice = true
                showToast(notice, duration: 4.5)
            }
        }
        .confirmationDialog("더보기", isPresented: $showingMore, titleVisibility: .hidden) {
            if !isPersisted {
                Button("저장") { save() }
            } else {
                Button(note.isFavorite ? "즐겨찾기 해제" : "즐겨찾기 추가") {
                    toggleFavorite()
                }
            }
            // 퀴즈 — 만들기/보기는 하단 액션바. 메뉴엔 카드 있을 때 "다시 만들기"만.
            if !note.flashcards.isEmpty {
                Button("퀴즈 다시 만들기") { showingQuizKindPicker = true }
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
        .overlay {
            if isGeneratingQuiz {
                ZStack {
                    Color.black.opacity(0.18).ignoresSafeArea()
                    ProgressView("퀴즈 만드는 중…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .fullScreenCover(isPresented: $showingStudy) {
            FlashcardStudyView(
                cards: note.flashcards.sorted { $0.createdAt < $1.createdAt },
                onClose: { showingStudy = false }
            )
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
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .confirmationDialog("어떤 퀴즈를 만들까요?", isPresented: $showingQuizKindPicker, titleVisibility: .visible) {
            Button("주관식 — 질문에 답하기") { generateQuiz(kind: .qa) }
            Button("OX 퀴즈 — 참 / 거짓 고르기") { generateQuiz(kind: .ox) }
            Button("취소", role: .cancel) {}
        }
        .errorAlert(error: $activeError) { action in
            // "내 키로 전환"을 눌렀는데 아직 Gemini 키가 없으면 바로 설정으로 안내한다.
            // (engine 전환만으로는 키가 없어 못 쓰므로.) 키가 있으면 그대로 전환되어 닫힌다.
            if action == .switchToOwnKey, !OCRPreferences.shared.hasGeminiKey {
                showingSettings = true
            }
        }
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
                ForEach(ColorCategory.activeInV01) { color in
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

    /// 퀴즈 버튼에 띄울 크레딧 비용. 만들기 모드 + Lumark Cloud일 때만 (본인 키=무제한이면 숨김).
    /// 값 2는 Worker COST_QUIZ 기본값과 맞춤.
    private var quizCostBadge: Int? {
        guard note.flashcards.isEmpty else { return nil }
        return OCRPreferences.shared.engine == .lumarkCloud ? 2 : nil
    }

    /// 정리된 노트 텍스트로 Q&A 카드 생성 → 저장 → 학습 화면.
    private func generateQuiz(kind: FlashcardKind) {
        guard !isGeneratingQuiz else { return }
        // 엔진이 퀴즈를 못 만드는 경우 로딩 없이 바로 안내(깜빡임 방지).
        switch QuizGenerator.support() {
        case .ready:
            break
        case .needsLogin:
            activeError = .wrapped(code: "QUIZ", message: "Lumark Cloud로 퀴즈를 만들려면 로그인이 필요해요. 설정 → 계정에서 로그인하거나, '내 Gemini 키'로 바꿔 주세요.")
            return
        case .needsKey:
            activeError = .wrapped(code: "QUIZ", message: "Gemini API 키가 없어요. 설정 → OCR 엔진에서 키를 등록하거나 'Lumark Cloud' 엔진을 쓰면 바로 만들 수 있어요.")
            return
        case .unsupportedEngine:
            activeError = .wrapped(code: "QUIZ", message: "지금 OCR 엔진(Apple Vision)으로는 퀴즈를 못 만들어요. 설정 → OCR 엔진에서 'Lumark Cloud'나 '내 Gemini 키'로 바꿔 주세요.")
            return
        }
        // 카드는 노트에 관계로 저장되므로 먼저 영속화. 저장 실패하면 중단.
        if !isPersisted {
            guard save() else { return }
        }
        isGeneratingQuiz = true

        let prefs = ExportPreferences.shared
        let text = MarkdownExporter.export(currentDoc, dialect: prefs.dialect, includePageMap: false)
        let provider = QuizGenerator.selectedProvider()
        let targetNote = note

        Task {
            do {
                let cards = try await provider.generate(from: text, count: 12, kind: kind)
                await MainActor.run {
                    isGeneratingQuiz = false
                    guard !cards.isEmpty else {
                        activeError = .wrapped(code: "QUIZ-EMPTY", message: "카드를 만들 내용이 부족해요.")
                        return
                    }
                    // 다시 만들기: 기존 카드 제거 후 교체
                    for old in targetNote.flashcards { modelContext.delete(old) }
                    for c in cards {
                        let card = Flashcard(question: c.question, answer: c.answer, kind: kind, oxAnswer: c.oxAnswer)
                        card.note = targetNote
                        modelContext.insert(card)
                    }
                    try? modelContext.save()
                    showToast("퀴즈 \(cards.count)장 만들었어요")
                    showingStudy = true
                }
            } catch let e as QuizError {
                await MainActor.run {
                    isGeneratingQuiz = false
                    // 크레딧 부족이면 "CREDITS" 코드로(본인 키 전환 액션 노출).
                    let code: String
                    if case .creditsExhausted = e { code = "CREDITS" } else { code = "QUIZ" }
                    activeError = .wrapped(code: code, message: e.errorDescription ?? "퀴즈 생성 실패")
                }
            } catch {
                await MainActor.run {
                    isGeneratingQuiz = false
                    activeError = .wrapped(code: "QUIZ", message: error.localizedDescription)
                }
            }
        }
    }

    private func copy() {
        let prefs = ExportPreferences.shared
        let md = MarkdownExporter.export(
            currentDoc,
            dialect: prefs.dialect,
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
            includePageMap: prefs.includePageMap
        )
        shareItems = [md]
    }

    private func exportPDF() {
        guard !isPreparingExport else { return }
        isPreparingExport = true
        let doc = currentDoc
        Task.detached(priority: .userInitiated) {
            do {
                let url = try PDFExporter.export(doc)
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

    private func showToast(_ text: String, duration: Double = 1.4) {
        withAnimation(.easeOut(duration: 0.15)) {
            toastMessage = text
        }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.15)) {
                    if toastMessage == text { toastMessage = nil }
                }
            }
        }
    }

    // MARK: - CRUD

    @discardableResult
    private func save() -> Bool {
        guard !isPersisted else { return true }
        // Note + Page + Highlight 그래프 전체 insert.
        // SwiftData는 root 한 번만 insert하면 relationship 따라 다 들어감.
        modelContext.insert(note)
        do {
            try modelContext.save()
            showToast("저장됨")
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return true
        } catch {
            activeError = .wrapped(code: "SAVE", message: "저장 실패: \(error.localizedDescription)")
            return false
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
        let deletedID = note.id   // 삭제 전에 id 확보(삭제 후엔 접근 위험)
        modelContext.delete(note)
        do {
            try modelContext.save()
            onDeleted?(deletedID)
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
