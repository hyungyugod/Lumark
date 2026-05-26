//
//  JobStateStore.swift
//  Lumark
//
//  처리 중 작업 상태를 디스크에 영속화. spec §8: "BG Task로 연장, 진행 상태 저장,
//  재진입 시 이어서". 콜드 재시작에서도 진행 상태 복구.
//
//  v0.1 디자인 단계: Mock 타이머라 실제 의미는 적지만, 실제 OCR 연결 시점에
//  이미 인프라가 깔려있도록 미리 만듦.
//

import Foundation
import UIKit

/// 재개 가능한 처리 작업 1개.
struct JobState: Codable, Identifiable, Sendable {
    let id: UUID
    let filename: String
    let totalPages: Int
    let stagedURL: URL?    // PDF인 경우, 임시 디렉토리에 stage된 URL
    let imageDataPath: String?  // 이미지인 경우 디스크 경로
    let isPDF: Bool
    var stageRaw: Int     // ProcessingViewModel.Stage.rawValue
    var currentPage: Int
    var startedAt: Date
    var lastUpdatedAt: Date

    nonisolated init(
        id: UUID = UUID(),
        filename: String,
        totalPages: Int,
        stagedURL: URL? = nil,
        imageDataPath: String? = nil,
        isPDF: Bool,
        stageRaw: Int = 0,
        currentPage: Int = 0,
        startedAt: Date = .now,
        lastUpdatedAt: Date = .now
    ) {
        self.id = id
        self.filename = filename
        self.totalPages = totalPages
        self.stagedURL = stagedURL
        self.imageDataPath = imageDataPath
        self.isPDF = isPDF
        self.stageRaw = stageRaw
        self.currentPage = currentPage
        self.startedAt = startedAt
        self.lastUpdatedAt = lastUpdatedAt
    }
}

@MainActor
@Observable
final class JobStateStore {
    static let shared = JobStateStore()

    private let fileURL: URL

    private(set) var jobs: [JobState] = []

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("lumark.jobs.json")
        self.jobs = (try? load()) ?? []
    }

    // MARK: - API

    /// 작업 시작 시 등록.
    func register(_ job: JobState) {
        jobs.removeAll { $0.id == job.id }
        jobs.append(job)
        save()
    }

    /// 진행 상태 업데이트.
    func update(id: UUID, stage: Int, currentPage: Int) {
        guard let idx = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[idx].stageRaw = stage
        jobs[idx].currentPage = currentPage
        jobs[idx].lastUpdatedAt = .now
        save()
    }

    /// 완료/취소 시 제거.
    func finish(id: UUID) {
        jobs.removeAll { $0.id == id }
        save()
    }

    /// 콜드 부팅 시 호출. 30분 이상 묵은 작업은 stale로 간주해 자동 제거.
    func purgeStale(olderThan: TimeInterval = 30 * 60) {
        let cutoff = Date().addingTimeInterval(-olderThan)
        let before = jobs.count
        jobs.removeAll { $0.lastUpdatedAt < cutoff }
        if jobs.count != before { save() }
    }

    /// 재개할 수 있는 가장 최근 작업 (UI에서 "이어서 진행" 표시용).
    var resumableJob: JobState? {
        jobs.sorted { $0.lastUpdatedAt > $1.lastUpdatedAt }.first
    }

    // MARK: - 디스크 I/O

    private func load() throws -> [JobState] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([JobState].self, from: data)
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(jobs)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // 저장 실패는 로깅만 (사용자에게 막다른 길 금지)
            print("[JobStateStore] save failed: \(error)")
        }
    }
}

// MARK: - 백그라운드 시간 연장 헬퍼

@MainActor
final class BackgroundTaskExtender {
    private var taskID: UIBackgroundTaskIdentifier = .invalid

    func begin(name: String) {
        end()
        taskID = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            self?.end()
        }
    }

    func end() {
        if taskID != .invalid {
            UIApplication.shared.endBackgroundTask(taskID)
            taskID = .invalid
        }
    }
}
