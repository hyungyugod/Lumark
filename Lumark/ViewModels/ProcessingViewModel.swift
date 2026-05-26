//
//  ProcessingViewModel.swift
//  Lumark
//
//  변환 진행 상태. v0.1 디자인 단계에서는 Mock 타이머로 진행.
//  Day 5+: 실제 파이프라인(HighlightDetector → OCRService → MarkdownExporter)으로 교체.
//

import Foundation
import SwiftUI

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

    /// 완료 후 결과 Note (Mock에서는 antibioticsNote 반환)
    var resultNote: Note? = nil

    /// JobStateStore와 매핑된 ID. nil이면 영속화 비활성.
    var jobID: UUID? = nil

    // MARK: - 내부

    private var task: Task<Void, Never>?
    private let bgExtender = BackgroundTaskExtender()

    init(totalPages: Int, jobID: UUID? = nil) {
        self.totalPages = totalPages
        self.jobID = jobID
    }

    // MARK: - 제어

    func start() {
        guard phase != .running else { return }
        phase = .running
        currentPage = 0
        currentStage = .splittingPages
        overallProgress = 0
        bgExtender.begin(name: "lumark.processing")
        task?.cancel()
        task = Task { await runMock() }
    }

    func cancel() {
        task?.cancel()
        phase = .cancelled
        bgExtender.end()
        if let jobID { JobStateStore.shared.finish(id: jobID) }
    }

    private func persistProgress() {
        guard let jobID else { return }
        JobStateStore.shared.update(
            id: jobID,
            stage: currentStage.rawValue,
            currentPage: currentPage
        )
    }

    // MARK: - Mock 진행

    private func runMock() async {
        // stage * page 매트릭스를 순회. 한 칸당 짧은 슬립.
        let stages = Stage.allCases
        let pages = max(1, totalPages)

        for stage in stages {
            currentStage = stage
            persistProgress()
            // OCR 단계는 페이지 단위 진행을 보여줌
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
        // 디자인 단계: 결과는 mock note로
        resultNote = MockData.antibioticsNote()
        phase = .finished
        bgExtender.end()
        if let jobID { JobStateStore.shared.finish(id: jobID) }
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
