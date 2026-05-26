//
//  DocumentScannerView.swift
//  Lumark
//
//  VNDocumentCameraViewController를 SwiftUI에서 쓸 수 있도록 wrap.
//  spec §1: "카메라 입력 (VNDocumentCameraViewController)".
//
//  자동 경계/원근/명도 보정이 들어가서 직접 사진 찍는 것보다 OCR 정확도가 높음.
//

import SwiftUI
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {

    /// 스캔 완료 시 호출. UIImage 배열 (페이지별).
    let onScanned: ([UIImage]) -> Void
    /// 사용자가 취소 또는 실패 시.
    let onCancel: () -> Void
    /// 시스템 에러.
    let onError: (Error) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned, onCancel: onCancel, onError: onError)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScanned: ([UIImage]) -> Void
        let onCancel: () -> Void
        let onError: (Error) -> Void

        init(
            onScanned: @escaping ([UIImage]) -> Void,
            onCancel: @escaping () -> Void,
            onError: @escaping (Error) -> Void
        ) {
            self.onScanned = onScanned
            self.onCancel = onCancel
            self.onError = onError
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            var images: [UIImage] = []
            images.reserveCapacity(scan.pageCount)
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            controller.dismiss(animated: true) { [self] in
                onScanned(images)
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) { [self] in
                onCancel()
            }
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            controller.dismiss(animated: true) { [self] in
                onError(error)
            }
        }
    }
}
