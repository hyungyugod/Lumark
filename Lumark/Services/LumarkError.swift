//
//  LumarkError.swift
//  Lumark
//
//  spec §8 13가지 케이스 매트릭스를 enum으로. 모든 에러는 두 가지 형태로:
//    - debugCode: 디버깅용 짧은 코드 (예: "OCR-EMPTY")
//    - userTitle: 사용자에게 보여줄 짧은 제목 (예: "감지되지 않았어요")
//    - userMessage: 더 긴 설명
//    - actions: 다음 행동 옵션들 (재시도, 설정 열기, 다른 파일 등)
//
//  spec §8 핵심 원칙 3가지를 코드로 강제:
//    1. 부분 성공 허용 (LumarkError.partialSuccess)
//    2. 데이터 절대 안 잃음 (각 에러는 사용자에게 다음 행동을 제시)
//    3. 막다른 길 금지 (.actions가 비어있는 경우 없음 — 최소 [확인])
//

import Foundation
import UIKit

enum LumarkError: Error, Equatable, Sendable {
    // MARK: 입력 단계
    /// 형광펜 영역 0개 감지
    case noHighlightsDetected
    /// PDF가 손상되어 열 수 없음
    case pdfCorrupted
    /// 입력이 너무 큼 (>50MB or >100페이지)
    case inputTooLarge(sizeMB: Double?, pages: Int?)
    /// 모든 페이지가 빈 페이지
    case allPagesBlank

    // MARK: 처리 단계
    /// OCR이 모든 highlight에서 빈 문자열 반환
    case ocrAllEmpty
    /// 사용자가 취소
    case cancelled
    /// 처리 중 메모리 부족
    case outOfMemory

    // MARK: 출력 단계
    /// 검출 영역 0개 (입력 자체에 형광펜 없음과 다른, 검출 실패)
    case detectionEmpty

    // MARK: 시스템
    /// 카메라 권한 거부
    case cameraPermissionDenied
    /// 사진 권한 거부
    case photosPermissionDenied
    /// 디스크 공간 부족
    case diskFull
    /// App Group 접근 실패 (AG-01)
    case appGroupAccessFailed
    /// 알 수 없는 파일 형식
    case unsupportedFormat

    // MARK: 부분 성공 (에러는 아니지만 안내가 필요)
    /// N페이지 중 M페이지 실패
    case partialSuccess(succeeded: Int, total: Int)

    /// wrap a generic error
    case wrapped(code: String, message: String)
}

// MARK: - User-facing 메타데이터

extension LumarkError {
    nonisolated var debugCode: String {
        switch self {
        case .noHighlightsDetected:    return "HL-EMPTY"
        case .pdfCorrupted:            return "PDF-CORRUPT"
        case .inputTooLarge:           return "INPUT-LARGE"
        case .allPagesBlank:           return "PAGES-BLANK"
        case .ocrAllEmpty:             return "OCR-EMPTY"
        case .cancelled:               return "CANCELLED"
        case .outOfMemory:             return "OOM"
        case .detectionEmpty:          return "DET-EMPTY"
        case .cameraPermissionDenied:  return "PERM-CAM"
        case .photosPermissionDenied:  return "PERM-PHOTO"
        case .diskFull:                return "DISK-FULL"
        case .appGroupAccessFailed:    return "AG-01"
        case .unsupportedFormat:       return "FMT-BAD"
        case .partialSuccess:          return "PART-OK"
        case .wrapped(let code, _):    return code
        }
    }

    nonisolated var userTitle: String {
        switch self {
        case .noHighlightsDetected:    return "감지되지 않았어요"
        case .pdfCorrupted:            return "파일을 열 수 없어요"
        case .inputTooLarge:           return "파일이 커요"
        case .allPagesBlank:           return "내용이 비어있어요"
        case .ocrAllEmpty:             return "글자 인식이 안 됐어요"
        case .cancelled:               return "취소됨"
        case .outOfMemory:             return "메모리가 부족해요"
        case .detectionEmpty:          return "감지 결과가 없어요"
        case .cameraPermissionDenied:  return "카메라 권한이 필요해요"
        case .photosPermissionDenied:  return "사진 권한이 필요해요"
        case .diskFull:                return "저장 공간이 부족해요"
        case .appGroupAccessFailed:    return "공유 설정 오류"
        case .unsupportedFormat:       return "지원하지 않는 형식"
        case .partialSuccess:          return "일부만 변환됐어요"
        case .wrapped(_, _):           return "오류가 발생했어요"
        }
    }

    nonisolated var userMessage: String {
        switch self {
        case .noHighlightsDetected:
            return "형광펜 표시를 찾지 못했어요. 사진을 더 밝게 찍거나 색 매핑을 확인해보세요."
        case .pdfCorrupted:
            return "PDF가 손상됐거나 열 수 없는 형식이에요."
        case .inputTooLarge(let mb, let pages):
            var parts: [String] = []
            if let mb { parts.append("\(Int(mb))MB") }
            if let pages { parts.append("\(pages)페이지") }
            let desc = parts.isEmpty ? "" : " (\(parts.joined(separator: ", ")))"
            return "큰 파일\(desc)이라 시간이 더 걸려요. 계속할까요?"
        case .allPagesBlank:
            return "모든 페이지가 비어있는 것 같아요."
        case .ocrAllEmpty:
            return "글자를 한 글자도 읽지 못했어요. 사진 화질을 확인해보세요."
        case .cancelled:
            return "사용자가 취소했어요."
        case .outOfMemory:
            return "큰 파일을 처리하느라 메모리가 부족해요. 페이지 수를 줄여보세요."
        case .detectionEmpty:
            return "표시된 영역이 하나도 없어요."
        case .cameraPermissionDenied:
            return "설정에서 카메라 권한을 켜주세요."
        case .photosPermissionDenied:
            return "설정에서 사진 권한을 켜주세요."
        case .diskFull:
            return "기기 저장 공간을 정리해주세요."
        case .appGroupAccessFailed:
            return "Code: AG-01. 앱을 재시작해주세요."
        case .unsupportedFormat:
            return "PDF 또는 이미지 파일만 지원해요."
        case .partialSuccess(let succeeded, let total):
            return "\(total)페이지 중 \(succeeded)페이지만 변환됐어요. 나머지는 인식 실패."
        case .wrapped(_, let message):
            return message
        }
    }

    /// 사용자가 다음에 할 수 있는 행동들. 빈 배열은 막다른 길 — 절대 두면 안 됨.
    nonisolated var defaultActions: [ErrorAction] {
        switch self {
        case .noHighlightsDetected, .detectionEmpty, .allPagesBlank, .ocrAllEmpty:
            return [.retry, .openSettings]
        case .pdfCorrupted, .unsupportedFormat:
            return [.tryAnotherFile]
        case .inputTooLarge:
            return [.proceed, .cancel]
        case .cancelled:
            return [.dismiss]
        case .outOfMemory, .diskFull:
            return [.dismiss]
        case .cameraPermissionDenied, .photosPermissionDenied:
            return [.openSystemSettings, .dismiss]
        case .appGroupAccessFailed:
            return [.dismiss]
        case .partialSuccess:
            return [.viewResult]
        case .wrapped:
            return [.dismiss]
        }
    }

    /// 에러 vs 경고 vs 안내. ErrorView 톤 결정에 사용.
    nonisolated var severity: ErrorSeverity {
        switch self {
        case .cancelled, .partialSuccess, .inputTooLarge:
            return .warning
        default:
            return .error
        }
    }
}

enum ErrorSeverity: Sendable {
    case error    // 빨강 톤
    case warning  // 황동 톤
    case info     // 회색
}

/// ErrorView가 노출하는 액션 종류. 부모가 핸들러를 주입.
enum ErrorAction: Equatable, Sendable {
    case retry
    case openSettings        // 앱 내 색 매핑 설정
    case openSystemSettings  // iOS 시스템 설정
    case tryAnotherFile
    case proceed
    case cancel
    case dismiss
    case viewResult

    nonisolated var label: String {
        switch self {
        case .retry:              return "다시 시도"
        case .openSettings:       return "설정 열기"
        case .openSystemSettings: return "시스템 설정"
        case .tryAnotherFile:     return "다른 파일"
        case .proceed:            return "계속"
        case .cancel:              return "취소"
        case .dismiss:             return "확인"
        case .viewResult:          return "결과 보기"
        }
    }

    nonisolated var isPrimary: Bool {
        switch self {
        case .retry, .proceed, .viewResult, .openSystemSettings: return true
        default: return false
        }
    }
}
