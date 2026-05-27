//
//  ProcessingViewModel.swift
//  Lumark
//
//  변환 진행 상태 + spec §5 파이프라인 오케스트레이션.
//
//  실 파이프라인 (source != nil):
//    PageRenderer → HighlightDetector → OCRService → Note 그래프 조립
//  Mock (source == nil): 디자인 단계 Preview 용 타이머 — antibioticsNote 반환.
//

import Foundation
import SwiftUI
import UIKit

@MainActor
@Observable
final class ProcessingViewModel {

    /// 처리 파이프라인의 stage (spec §5)
    enum Stage: Int, CaseIterable, Identifiable {
        case splittingPages
        case detectingHighlights
        case ocr
        case assembling

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .splittingPages:      return "페이지 분리"
            case .detectingHighlights: return "형광펜 검출"
            case .ocr:                 return "OCR"
            case .assembling:          return "마크다운 조립"
            }
        }

        var icon: String {
            switch self {
            case .splittingPages:      return "doc.on.doc"
            case .detectingHighlights: return "highlighter"
            case .ocr:                 return "text.viewfinder"
            case .assembling:          return "list.bullet.indent"
            }
        }
    }

    enum PhaseState {
        case idle
        case running
        case cancelled
        case finished
    }

    // MARK: - 외부 상태

    var totalPages: Int
    var currentPage: Int = 0
    var currentStage: Stage = .splittingPages
    var phase: PhaseState = .idle
    var overallProgress: Double = 0   // 0..1

    /// 완료 후 결과 Note. SwiftData 저장은 ResultView가 담당.
    var resultNote: Note? = nil

    /// 파이프라인 실패 시 채워짐. spec §8 케이스. view가 alert로 표시.
    var error: LumarkError? = nil

    /// JobStateStore와 매핑된 ID. nil이면 영속화 비활성.
    var jobID: UUID? = nil

    /// 입력 소스. nil이면 Mock 경로 — 디자인 Preview 및 source 없는 진입 보호.
    let source: JobSource?

    // MARK: - 내부

    private var task: Task<Void, Never>?
    private let bgExtender = BackgroundTaskExtender()
    private let resumeFrom: JobState?

    init(
        totalPages: Int,
        source: JobSource? = nil,
        jobID: UUID? = nil,
        resumeFrom: JobState? = nil
    ) {
        self.totalPages = totalPages
        self.source = source
        self.jobID = jobID
        self.resumeFrom = resumeFrom

        if let r = resumeFrom {
            self.currentStage = Stage(rawValue: r.stageRaw) ?? .splittingPages
            self.currentPage = r.currentPage
        }
    }

    // MARK: - 제어

    func start() {
        guard phase != .running else { return }
        phase = .running
        if resumeFrom == nil {
            currentPage = 0
            currentStage = .splittingPages
            overallProgress = 0
        }
        bgExtender.begin(name: "lumark.processing")
        task?.cancel()
        if let source {
            task = Task { await runReal(source: source) }
        } else {
            task = Task { await runMock() }
        }
    }

    func cancel() {
        task?.cancel()
        phase = .cancelled
        bgExtender.end()
    }

    private func persistProgress() {
        guard let jobID else { return }
        JobStateStore.shared.update(
            id: jobID,
            stage: currentStage.rawValue,
            currentPage: currentPage
        )
    }

    private func setStage(_ s: Stage) {
        currentStage = s
        persistProgress()
    }

    // MARK: - 실 파이프라인

    private func runReal(source: JobSource) async {
        do {
            // 1. 페이지 분리
            setStage(.splittingPages)
            let pages: [UIImage] = try await renderPages(from: source)
            if Task.isCancelled { return }
            guard !pages.isEmpty else {
                throw LumarkError.allPagesBlank
            }
            totalPages = pages.count
            overallProgress = stagePortion(.splittingPages)

            // 2. 형광펜 검출
            setStage(.detectingHighlights)
            let rules = ColorRuleStore.shared.rules
            var perPageRegions: [[DetectedRegion]] = []
            perPageRegions.reserveCapacity(pages.count)
            for (idx, img) in pages.enumerated() {
                if Task.isCancelled { return }
                currentPage = idx + 1
                let regions = await Task.detached(priority: .userInitiated) {
                    HighlightDetector.detect(in: img, rules: rules)
                }.value
                perPageRegions.append(regions)
                let frac = Double(idx + 1) / Double(pages.count)
                overallProgress = baseProgress(.detectingHighlights)
                    + frac * stagePortion(.detectingHighlights)
            }

            let totalRegions = perPageRegions.reduce(0) { $0 + $1.count }
            guard totalRegions > 0 else {
                throw LumarkError.noHighlightsDetected
            }

            // 3. OCR — 페이지 단위 진행 표시
            setStage(.ocr)
            currentPage = 0
            var perPageTexts: [[String]] = []
            perPageTexts.reserveCapacity(pages.count)
            for (idx, regions) in perPageRegions.enumerated() {
                if Task.isCancelled { return }
                currentPage = idx + 1
                let texts = await OCRService.recognize(in: pages[idx], regions: regions)
                perPageTexts.append(texts)
                persistProgress()
                let frac = Double(idx + 1) / Double(pages.count)
                overallProgress = baseProgress(.ocr) + frac * stagePortion(.ocr)
            }

            // OCR이 모두 빈 문자열이면 spec §8 .ocrAllEmpty
            let totalRecognized = perPageTexts.reduce(0) { acc, page in
                acc + page.filter { !$0.isEmpty }.count
            }
            guard totalRecognized > 0 else {
                throw LumarkError.ocrAllEmpty
            }

            // 4. 조립 — Note + Page + Highlight 그래프 빌드
            setStage(.assembling)
            let note = assembleNote(
                source: source,
                pages: pages,
                perPageRegions: perPageRegions,
                perPageTexts: perPageTexts
            )

            if Task.isCancelled { return }
            currentPage = pages.count
            overallProgress = 1.0
            resultNote = note
            phase = .finished
            bgExtender.end()
        } catch let err as LumarkError {
            self.error = err
            phase = .cancelled
            bgExtender.end()
        } catch is CancellationError {
            phase = .cancelled
            bgExtender.end()
        } catch {
            self.error = .wrapped(code: "PROC-FAIL", message: error.localizedDescription)
            phase = .cancelled
            bgExtender.end()
        }
    }

    // MARK: - 페이지 렌더

    private func renderPages(from source: JobSource) async throws -> [UIImage] {
        switch source {
        case .pdf(let url):
            do {
                return try await PageRenderer.renderPDF(at: url, didIndex: { [weak self] cur, total in
                    Task { @MainActor in
                        self?.currentPage = cur
                        // 페이지 분리 stage 내에서 fine-grained 진행률
                        let frac = Double(cur) / Double(max(1, total))
                        self?.overallProgress = frac * (self?.stagePortion(.splittingPages) ?? 0.10)
                    }
                })
            } catch PageRendererError.cannotOpenPDF, PageRendererError.emptyPDF {
                throw LumarkError.pdfCorrupted
            }
        case .image(let data):
            return try PageRenderer.render(imageData: data)
        }
    }

    // MARK: - Note 조립

    private func assembleNote(
        source: JobSource,
        pages: [UIImage],
        perPageRegions: [[DetectedRegion]],
        perPageTexts: [[String]]
    ) -> Note {
        let (sourceKind, filename) = sourceMeta(source: source)
        let title = noteTitle(from: filename)

        let note = Note(
            title: title,
            createdAt: .now,
            source: sourceKind,
            pageCount: pages.count,
            originalFilename: filename
        )

        // SwiftData @Model 관계: ModelContext 밖에선 append가 불안정.
        // 배열 통째로 할당해 양방향이 확실히 묶이도록 한다.
        var allPages: [Page] = []
        for (idx, image) in pages.enumerated() {
            let pageData = image.jpegData(compressionQuality: 0.78) ?? Data()
            let page = Page(pageNumber: idx + 1, imageData: pageData)
            page.note = note

            let regions = perPageRegions[idx]
            let texts = perPageTexts[idx]
            var hs: [Highlight] = []
            var order = 0
            for (rIdx, region) in regions.enumerated() {
                let text = rIdx < texts.count ? texts[rIdx] : ""
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }   // OCR 빈 문자열 highlight는 스킵 (spec §8)
                let h = Highlight(
                    colorCategory: region.color,
                    text: trimmed,
                    boundingBoxData: encode(rect: region.boundingBox),
                    orderInPage: order
                )
                h.page = page
                hs.append(h)
                order += 1
            }
            page.highlights = hs
            allPages.append(page)
        }
        note.pages = allPages
        return note
    }

    private func sourceMeta(source: JobSource) -> (NoteSource, String?) {
        switch source {
        case .pdf(let url):
            return (.pdf, url.lastPathComponent)
        case .image:
            return (.image, nil)
        }
    }

    /// 파일명에서 확장자를 떼고 노트 제목으로. 빈 문자열이면 기본 제목.
    private func noteTitle(from filename: String?) -> String {
        guard let filename, !filename.isEmpty else { return defaultTitle() }
        let base = (filename as NSString).deletingPathExtension
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultTitle() : trimmed
    }

    private func defaultTitle() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 HH:mm 스캔"
        return f.string(from: .now)
    }

    /// CGRect → Data (Highlight.boundingBoxData). withUnsafeBytes 패턴 — MockData와 동일.
    private func encode(rect: CGRect) -> Data {
        withUnsafeBytes(of: rect) { Data($0) }
    }

    // MARK: - Mock 진행 (디자인/Preview)

    private func runMock() async {
        let stages = Stage.allCases
        let pages = max(1, totalPages)

        for stage in stages {
            currentStage = stage
            persistProgress()
            if stage == .ocr {
                for p in 1...pages {
                    if Task.isCancelled { return }
                    currentPage = p
                    overallProgress = baseProgress(stage) + Double(p) / Double(pages) * stagePortion(stage)
                    persistProgress()
                    try? await Task.sleep(nanoseconds: 320_000_000)
                }
            } else {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 700_000_000)
                overallProgress = baseProgress(stage) + stagePortion(stage)
            }
        }

        if Task.isCancelled { return }
        currentPage = pages
        overallProgress = 1.0
        resultNote = MockData.antibioticsNote()
        phase = .finished
        bgExtender.end()
    }

    /// stage 시작 시점의 누적 진행률 기준값
    private func baseProgress(_ stage: Stage) -> Double {
        Stage.allCases
            .prefix(while: { $0 != stage })
            .map { stagePortion($0) }
            .reduce(0, +)
    }

    /// stage가 전체 진행률에서 차지하는 비중
    private func stagePortion(_ stage: Stage) -> Double {
        switch stage {
        case .splittingPages:      return 0.10
        case .detectingHighlights: return 0.20
        case .ocr:                 return 0.55
        case .assembling:          return 0.15
        }
    }
}
