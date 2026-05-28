//
//  OCRService.swift
//  Lumark
//
//  spec §5 step 3 — 형광펜 영역만 잘라 한국어 인쇄체 OCR.
//
//  Vision Framework (`VNRecognizeTextRequest`)을 .accurate + ko-KR 우선으로 사용.
//  단일 highlight = 한 줄 또는 두세 단어가 대부분이라 인식 결과를 공백으로 이어붙임.
//
//  Day 2~4 S2 합격선 (spec §7): CER ≤ 5%, WER ≤ 10%.
//  실패한 highlight는 빈 문자열을 반환 — 호출자가 spec §8 ".ocrAllEmpty" 케이스로
//  부분 성공 판정에 사용.
//

import Foundation
import UIKit
import Vision

nonisolated enum OCRService {

    /// 검출 영역들을 OCR. 결과는 입력 순서를 유지.
    /// - parameters:
    ///   - image: 페이지 전체 UIImage
    ///   - regions: HighlightDetector가 만든 영역들
    /// - returns: regions와 같은 길이의 OCR 텍스트 배열. 실패한 영역은 빈 문자열.
    static func recognize(
        in image: UIImage,
        regions: [DetectedRegion]
    ) async -> [String] {
        guard !regions.isEmpty, let cg = image.cgImage else { return [] }

        var out = [String](repeating: "", count: regions.count)
        for (idx, region) in regions.enumerated() {
            if Task.isCancelled { break }
            out[idx] = await recognizeOne(cgImage: cg, bbox: region.boundingBox)
        }
        return out
    }

    /// 페이지 전체에 한 번만 OCR을 돌려놓고, 각 영역의 텍스트를 추출하는 빠른 경로.
    /// (영역마다 자르는 것보다 빠르지만 정확도는 약간 떨어짐 — fallback으로 사용.)
    static func recognizeWhole(in image: UIImage) async -> [VNRecognizedTextObservation] {
        guard let cg = image.cgImage else { return [] }
        return await runRequest(on: cg)
    }

    // MARK: - 영역 단위 OCR

    private static func recognizeOne(cgImage: CGImage, bbox: CGRect) async -> String {
        // bbox는 입력 픽셀 좌표 → CGImage 좌표 그대로 사용 가능
        let imageW = CGFloat(cgImage.width)
        let imageH = CGFloat(cgImage.height)
        let safe = bbox.intersection(CGRect(x: 0, y: 0, width: imageW, height: imageH))
        guard !safe.isNull, !safe.isEmpty else { return "" }

        guard let cropped = cgImage.cropping(to: safe) else { return "" }
        let observations = await runRequest(on: cropped)
        return joinObservations(observations)
    }

    /// 한 CGImage에 대해 Vision OCR 요청을 돌리고 observation 배열을 반환.
    private static func runRequest(on cgImage: CGImage) async -> [VNRecognizedTextObservation] {
        await withCheckedContinuation { (continuation: CheckedContinuation<[VNRecognizedTextObservation], Never>) in
            let request = VNRecognizeTextRequest { req, _ in
                let obs = (req.results as? [VNRecognizedTextObservation]) ?? []
                continuation.resume(returning: obs)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            // ko-KR만 사용. en-US를 함께 두면 Vision이 한국어 조사 "이"를 라틴 "O"로
            // 잘못 추론하는 사례(예: "FHR이" → "FHRO")가 발생. ko-KR 모델은 한국어
            // 문서에 흔히 섞인 라틴 단어(hypertrophy 등)도 충분히 잘 읽는다.
            request.recognitionLanguages = ["ko-KR"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    // MARK: - 결과 합치기

    /// observation의 top candidate를 위→아래, 왼→오른쪽 순으로 이어 붙임.
    /// 같은 줄이면 공백, 줄이 바뀌면 공백 한 칸 (한글 본문에선 줄바꿈 = 공백 취급이 자연스러움).
    private static func joinObservations(_ observations: [VNRecognizedTextObservation]) -> String {
        // Vision은 normalized + 좌하단 원점이므로 minY 큰 게 먼저 (위쪽).
        let sorted = observations.sorted { lhs, rhs in
            let yBin = lineBin(lhs.boundingBox.midY)
            let yBinR = lineBin(rhs.boundingBox.midY)
            if yBin != yBinR { return yBin > yBinR }   // 큰 y = 위
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }
        let pieces = sorted.compactMap { $0.topCandidates(1).first?.string }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return pieces.joined(separator: " ")
    }

    /// 0.03 = 3% 단위로 양자화. 한 줄짜리 highlight 안에서는 보통 같은 줄로 묶임.
    private static func lineBin(_ y: CGFloat) -> Int {
        Int(y / 0.03)
    }
}
