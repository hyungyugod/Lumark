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
}

/// 변환 입력 소스.
enum JobSource {
    case image(Data)
    case pdf(URL)
}

/// 메모리 상의 진행 중 잡 (영속화는 JobStateStore에서 별도).
struct PendingJob: Identifiable {
    let id: UUID
    let filename: String
    let totalPages: Int
    let source: JobSource
}
