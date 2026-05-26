//
//  PermissionService.swift
//  Lumark
//
//  카메라 / 사진 권한 체크 + 요청 + 시스템 설정 열기.
//  spec §8 "카메라 권한 거부" 케이스.
//

import Foundation
import AVFoundation
import Photos
import UIKit

@MainActor
enum PermissionService {

    enum Status {
        case authorized
        case denied
        case undetermined
        case restricted
    }

    // MARK: - 카메라

    /// 현재 카메라 권한 상태.
    static var cameraStatus: Status {
        map(AVCaptureDevice.authorizationStatus(for: .video))
    }

    /// 카메라 권한 요청. 이미 결정된 상태면 즉시 반환.
    static func requestCamera() async -> Status {
        switch cameraStatus {
        case .undetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .authorized : .denied
        case let other:
            return other
        }
    }

    // MARK: - 사진

    /// 현재 사진 권한 상태. PhotosPicker는 limited access 없이 working — 사진 권한은
    /// 옵션이지만 PHPhotoLibrary 접근 시 필요.
    static var photosStatus: Status {
        let raw = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch raw {
        case .authorized, .limited: return .authorized
        case .denied:               return .denied
        case .notDetermined:        return .undetermined
        case .restricted:           return .restricted
        @unknown default:           return .denied
        }
    }

    static func requestPhotos() async -> Status {
        let raw = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        switch raw {
        case .authorized, .limited: return .authorized
        case .denied:               return .denied
        case .restricted:           return .restricted
        case .notDetermined:        return .undetermined
        @unknown default:           return .denied
        }
    }

    // MARK: - 시스템 설정 열기

    /// 시스템 설정의 이 앱 페이지를 연다.
    static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - helpers

    private static func map(_ s: AVAuthorizationStatus) -> Status {
        switch s {
        case .authorized:    return .authorized
        case .denied:        return .denied
        case .notDetermined: return .undetermined
        case .restricted:    return .restricted
        @unknown default:    return .denied
        }
    }
}
