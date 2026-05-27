//
//  OCRServiceTests.swift
//  LumarkTests
//
//  OCRService는 Vision Framework에 위임하는 얇은 래퍼라 contract만 검증한다.
//  진짜 한국어 인식 정확도(CER/WER)는 Day 2~4 합격 게이트에서 ground truth로
//  별도 측정.
//
//  여기서 잠그는 invariant:
//    1. 빈 regions 입력 → 빈 결과
//    2. 호출이 크래시 없이 끝나고, regions와 같은 길이의 결과를 돌려준다
//    3. 합성된 영문 텍스트 이미지에 대해 빈 문자열이 아닌 결과를 돌려준다 (smoke)
//

import Testing
import Foundation
import UIKit
@testable import Lumark

@Suite("OCRService — contract smoke")
struct OCRServiceTests {

    @Test("빈 regions는 빈 결과")
    func emptyRegionsYieldsEmpty() async {
        let img = UIImage(systemName: "doc.text") ?? UIImage()
        let result = await OCRService.recognize(in: img, regions: [])
        #expect(result.isEmpty)
    }

    @Test("regions 길이만큼 결과 반환")
    func resultLengthMatchesRegions() async {
        let img = whitePage()
        // 빈 영역 두 개 — 결과는 빈 문자열 두 개 (크래시 없이)
        let regions = [
            DetectedRegion(
                color: .yellow,
                boundingBox: CGRect(x: 10, y: 10, width: 40, height: 40),
                area: 100
            ),
            DetectedRegion(
                color: .orange,
                boundingBox: CGRect(x: 60, y: 60, width: 40, height: 40),
                area: 100
            ),
        ]
        let result = await OCRService.recognize(in: img, regions: regions)
        #expect(result.count == regions.count)
    }

    @Test("영문 텍스트 합성 이미지에 대해 비어있지 않은 OCR 결과")
    func englishTextSmoke() async {
        let img = textImage("HELLO WORLD")
        let region = DetectedRegion(
            color: .yellow,
            boundingBox: CGRect(origin: .zero, size: img.size),
            area: Int(img.size.width * img.size.height)
        )
        let result = await OCRService.recognize(in: img, regions: [region])
        #expect(result.count == 1)
        // Vision은 거의 항상 영문 인쇄체에 강함. 빈 문자열이 아니어야 함.
        // (한국어 합성은 폰트 의존이 커서 smoke 대상 외)
        #expect(!result[0].isEmpty)
    }

    // MARK: - 헬퍼

    private func whitePage(size: CGSize = CGSize(width: 200, height: 200)) -> UIImage {
        let r = UIGraphicsImageRenderer(size: size)
        return r.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func textImage(_ text: String) -> UIImage {
        let size = CGSize(width: 600, height: 200)
        // scale=1 — img.size(points) == CGImage 픽셀 크기. bbox 좌표가 일치하도록.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let r = UIGraphicsImageRenderer(size: size, format: format)
        return r.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 80, weight: .bold),
                .foregroundColor: UIColor.black,
            ]
            let attributed = NSAttributedString(string: text, attributes: attrs)
            attributed.draw(at: CGPoint(x: 30, y: 50))
        }
    }
}
