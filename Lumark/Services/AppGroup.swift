//
//  AppGroup.swift
//  Lumark
//
//  Share Extension과 메인 앱이 공유하는 App Group 폴더 헬퍼.
//  spec §4 데이터 흐름:
//    1. Share Extension이 받은 파일을 Inbox/{uuid}.{ext} 로 저장
//    2. /Inbox/{uuid}.json 에 메타 (원본 파일명, 받은 시각, 타입)
//    3. lumark://import?id={uuid} deeplink로 메인 앱 호출
//    4. 메인 앱이 onOpenURL에서 Inbox 로드 → ProcessingView
//

import Foundation

enum AppGroup {

    /// App Group identifier. Xcode Capabilities에서 동일한 값으로 등록 필요.
    /// 메인 앱 + Share Extension target 양쪽 다.
    static let id = "group.com.lumark"

    /// 공유 컨테이너 루트. Capability가 등록되어있지 않으면 nil 반환.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }

    /// Inbox 폴더 — Share Extension이 파일 stage하는 곳.
    static var inboxURL: URL? {
        containerURL?.appendingPathComponent("Inbox", isDirectory: true)
    }

    /// Inbox 폴더 생성 (없으면).
    @discardableResult
    static func ensureInbox() -> URL? {
        guard let url = inboxURL else { return nil }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - 파일 stage / 로드

    struct InboxItemMeta: Codable, Sendable {
        let id: UUID
        let originalFilename: String
        let utiHint: String          // "pdf" / "image"
        let receivedAt: Date
        let dataFilename: String     // {id}.{ext}

        nonisolated init(
            id: UUID,
            originalFilename: String,
            utiHint: String,
            receivedAt: Date,
            dataFilename: String
        ) {
            self.id = id
            self.originalFilename = originalFilename
            self.utiHint = utiHint
            self.receivedAt = receivedAt
            self.dataFilename = dataFilename
        }
    }

    /// Share Extension에서 호출 — 받은 데이터를 Inbox에 저장하고 ID 반환.
    /// 반환된 ID를 deeplink에 실어 메인 앱으로 던짐.
    static func stage(data: Data, originalFilename: String, isPDF: Bool) throws -> UUID {
        guard let inbox = ensureInbox() else {
            throw NSError(
                domain: "AppGroup", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "App Group 접근 실패 (Code: AG-01)"]
            )
        }
        let id = UUID()
        let ext = isPDF ? "pdf" : (originalFilename as NSString).pathExtension.nonEmptyOrDefault("img")
        let dataName = "\(id.uuidString).\(ext)"
        let dataURL = inbox.appendingPathComponent(dataName)
        try data.write(to: dataURL, options: .atomic)

        let meta = InboxItemMeta(
            id: id,
            originalFilename: originalFilename,
            utiHint: isPDF ? "pdf" : "image",
            receivedAt: .now,
            dataFilename: dataName
        )
        let metaURL = inbox.appendingPathComponent("\(id.uuidString).json")
        let metaData = try JSONEncoder().encode(meta)
        try metaData.write(to: metaURL, options: .atomic)

        return id
    }

    /// 메인 앱에서 호출 — deeplink ID로 Inbox에서 메타 + 데이터 URL 로드.
    static func load(id: UUID) throws -> (meta: InboxItemMeta, dataURL: URL) {
        guard let inbox = inboxURL else {
            throw NSError(domain: "AppGroup", code: 1)
        }
        let metaURL = inbox.appendingPathComponent("\(id.uuidString).json")
        let metaData = try Data(contentsOf: metaURL)
        let meta = try JSONDecoder().decode(InboxItemMeta.self, from: metaData)
        let dataURL = inbox.appendingPathComponent(meta.dataFilename)
        guard FileManager.default.fileExists(atPath: dataURL.path) else {
            throw NSError(
                domain: "AppGroup", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Inbox 데이터 누락"]
            )
        }
        return (meta, dataURL)
    }

    /// Inbox 항목 정리 — 메인 앱이 처리 완료한 후 호출.
    static func cleanup(id: UUID) {
        guard let inbox = inboxURL else { return }
        let meta = inbox.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: meta)
        // 데이터 파일은 메타에서 이름 가져왔지만 안전하게 디렉토리 스캔
        if let entries = try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil) {
            for url in entries where url.lastPathComponent.hasPrefix(id.uuidString) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}

private extension String {
    func nonEmptyOrDefault(_ d: String) -> String { isEmpty ? d : self }
}
