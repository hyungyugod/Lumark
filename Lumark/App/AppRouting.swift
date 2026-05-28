//
//  AppRouting.swift
//  Lumark
//
//  HomeView에서 사용하는 라우팅/잡 타입들. HomeView에서 분리.
//

import Foundation

/// HomeView의 NavigationStack 경로 값.
enum HomeRoute: Hashable {
    case processing(jobID: UUID)
    case result(noteID: UUID)
    case recentList
    case myQuizzes
}

/// 변환 입력 소스.
/// - `images` 는 N장(1~100). PhotosPicker 다중 선택 / 카메라 다중 스캔이 모두 통과.
/// - `pdf` 는 다중 페이지 파일 1개.
enum JobSource: Sendable {
    case images([Data])
    case pdf(URL)
}

/// 메모리 상의 진행 중 잡 (영속화는 JobStateStore에서 별도).
/// `inboxID`가 nil이 아니면 Share Extension에서 진입한 잡 → 처리 끝난 후
/// AppGroup.cleanup(id: inboxID)로 inbox 파일을 정리해야 한다.
struct PendingJob: Identifiable {
    let id: UUID
    let filename: String
    let totalPages: Int
    let source: JobSource
    let inboxID: UUID?
}
