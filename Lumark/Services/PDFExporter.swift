//
//  PDFExporter.swift
//  Lumark
//
//  MarkdownDocument → PDF (Letter 사이즈, 다중 페이지 자동 분할).
//
//  spec §6 출력을 디자인 톤(serif 제목 + sans 본문 + 컬러 글머리)으로 렌더.
//  좌측 컬러 바는 PDF에서는 색상 글머리표(●)로 단순화.
//

import Foundation
import UIKit
import CoreText

enum PDFExporterError: Error, LocalizedError {
    case cannotCreatePDF
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .cannotCreatePDF:        return "PDF를 만들 수 없어요"
        case .writeFailed(let e):     return "파일 저장 실패: \(e.localizedDescription)"
        }
    }
}

/// MarkdownDocument → PDF. URL 반환.
nonisolated enum PDFExporter {

    /// 페이지 사이즈: A4 (210x297 mm @ 72 DPI ≈ 595x842).
    /// 한국 환경 + 시험·강의 자료는 보통 A4 친화적.
    private static let pageSize = CGSize(width: 595, height: 842)
    private static let pageMargin: CGFloat = 56

    static func export(
        _ doc: MarkdownDocument,
        pinkLabel: String? = nil,
        blueLabel: String? = nil
    ) throws -> URL {

        let attr = buildAttributedString(
            from: doc,
            pinkLabel: pinkLabel,
            blueLabel: blueLabel
        )

        let pageBounds = CGRect(origin: .zero, size: pageSize)
        let textBounds = pageBounds.insetBy(dx: pageMargin, dy: pageMargin)

        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        let data = renderer.pdfData { ctx in
            // CoreText로 frame 단위 페이지 분할
            let framesetter = CTFramesetterCreateWithAttributedString(attr as CFAttributedString)
            let textLength = attr.length

            var currentIndex = 0
            while currentIndex < textLength {
                ctx.beginPage()
                drawPageBackground(in: pageBounds)

                let path = CGPath(rect: textBounds, transform: nil)
                let frame = CTFramesetterCreateFrame(
                    framesetter,
                    CFRange(location: currentIndex, length: 0),
                    path,
                    nil
                )

                // 그리기 — PDF context는 좌하단 원점이므로 뒤집기
                let cg = ctx.cgContext
                cg.saveGState()
                cg.translateBy(x: 0, y: pageBounds.height)
                cg.scaleBy(x: 1, y: -1)
                CTFrameDraw(frame, cg)
                cg.restoreGState()

                // 다음 페이지로 — 이 프레임에서 소비된 글자 수만큼
                let visibleRange = CTFrameGetVisibleStringRange(frame)
                let consumed = visibleRange.length
                if consumed == 0 { break } // 무한루프 방지
                currentIndex += consumed

                // 페이지 번호 (선택적)
            }
        }

        // 파일 저장
        let url = try writeToFile(data: data, suggestedName: doc.title)
        return url
    }

    // MARK: - NSAttributedString 빌드

    private static func buildAttributedString(
        from doc: MarkdownDocument,
        pinkLabel: String?,
        blueLabel: String?
    ) -> NSAttributedString {
        let out = NSMutableAttributedString()

        // 제목
        out.append(NSAttributedString(string: "\(doc.title)\n\n", attributes: titleAttrs()))

        // 본문 섹션
        for section in doc.sections {
            let title = section.title ?? "(주제 미지정)"
            out.append(NSAttributedString(string: "\(title)\n\n", attributes: sectionTitleAttrs()))

            for item in section.items {
                out.append(bullet(text: item.text, color: item.color))
            }

            if !section.items.isEmpty {
                out.append(NSAttributedString(string: "\n", attributes: bodyAttrs()))
            }
        }

        // 추가 메모
        if doc.hasSupplementary {
            out.append(NSAttributedString(string: "\n", attributes: bodyAttrs()))
            out.append(divider())
            out.append(NSAttributedString(string: "추가 메모\n\n", attributes: subTitleAttrs()))

            if !doc.pinkItems.isEmpty {
                let label = pinkLabel?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                    ?? "보충 (분홍)"
                out.append(NSAttributedString(string: "\(label)\n", attributes: emphAttrs()))
                for item in doc.pinkItems {
                    out.append(bullet(text: item.text, color: .pink))
                }
                out.append(NSAttributedString(string: "\n", attributes: bodyAttrs()))
            }

            if !doc.blueItems.isEmpty {
                let label = blueLabel?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                    ?? "참고 (파랑)"
                out.append(NSAttributedString(string: "\(label)\n", attributes: emphAttrs()))
                for item in doc.blueItems {
                    out.append(bullet(text: item.text, color: .blue))
                }
                out.append(NSAttributedString(string: "\n", attributes: bodyAttrs()))
            }
        }

        // 변환 정보 footer
        out.append(divider())
        out.append(NSAttributedString(string: footerText(for: doc), attributes: footerAttrs()))

        return out
    }

    // MARK: - 글머리표 한 줄

    /// "● 본문" — 좌측 컬러 표시 + indent.
    private static func bullet(text: String, color: ColorCategory) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.firstLineHeadIndent = 0
        paragraph.headIndent = 18
        paragraph.paragraphSpacing = 2
        paragraph.lineSpacing = 2

        let result = NSMutableAttributedString()
        let bulletAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .black),
            .foregroundColor: uiColor(for: color),
            .paragraphStyle: paragraph,
            .baselineOffset: 1.5,
        ]
        result.append(NSAttributedString(string: "●  ", attributes: bulletAttrs))

        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor(red: 0.30, green: 0.27, blue: 0.23, alpha: 1), // ink-2
            .paragraphStyle: paragraph,
        ]
        result.append(NSAttributedString(string: "\(text)\n", attributes: textAttrs))
        return result
    }

    // MARK: - 구분선

    private static func divider() -> NSAttributedString {
        let p = NSMutableParagraphStyle()
        p.alignment = .left
        p.lineSpacing = 6
        return NSAttributedString(
            string: "─────────────────\n\n",
            attributes: [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor(white: 0.75, alpha: 1),
                .paragraphStyle: p,
            ]
        )
    }

    // MARK: - footer

    private static func footerText(for doc: MarkdownDocument) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy-MM-dd"
        let filename = doc.originalFilename ?? "\(doc.title).pdf"
        return "변환 정보: \(filename) · \(doc.pageCount)페이지 · \(f.string(from: doc.createdAt)) 변환"
    }

    // MARK: - 스타일 헬퍼

    private static let inkColor = UIColor(red: 0.21, green: 0.20, blue: 0.18, alpha: 1)
    private static let ink2Color = UIColor(red: 0.30, green: 0.27, blue: 0.23, alpha: 1)
    private static let subtleColor = UIColor(red: 0.50, green: 0.46, blue: 0.41, alpha: 1)

    private static func titleAttrs() -> [NSAttributedString.Key: Any] {
        let p = NSMutableParagraphStyle()
        p.paragraphSpacing = 4
        return [
            .font: UIFont(name: "NanumMyeongjo-ExtraBold", size: 24)
                ?? UIFont.systemFont(ofSize: 24, weight: .heavy),
            .foregroundColor: inkColor,
            .paragraphStyle: p,
        ]
    }
    private static func sectionTitleAttrs() -> [NSAttributedString.Key: Any] {
        let p = NSMutableParagraphStyle()
        p.paragraphSpacingBefore = 14
        p.paragraphSpacing = 4
        return [
            .font: UIFont(name: "NanumMyeongjo-Bold", size: 16)
                ?? UIFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: inkColor,
            .paragraphStyle: p,
        ]
    }
    private static func subTitleAttrs() -> [NSAttributedString.Key: Any] {
        return [
            .font: UIFont(name: "NanumMyeongjo-Bold", size: 13)
                ?? UIFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: inkColor,
        ]
    }
    private static func emphAttrs() -> [NSAttributedString.Key: Any] {
        return [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: inkColor,
        ]
    }
    private static func bodyAttrs() -> [NSAttributedString.Key: Any] {
        return [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: ink2Color,
        ]
    }
    private static func footerAttrs() -> [NSAttributedString.Key: Any] {
        let p = NSMutableParagraphStyle()
        p.paragraphSpacingBefore = 8
        return [
            .font: UIFont.italicSystemFont(ofSize: 10),
            .foregroundColor: subtleColor,
            .paragraphStyle: p,
        ]
    }

    private static func uiColor(for color: ColorCategory) -> UIColor {
        // Theme의 oklch 변환 재사용 — 단순화: 시안에 가까운 sRGB 근사
        switch color {
        case .yellow: return UIColor(red: 0.95, green: 0.78, blue: 0.20, alpha: 1)
        case .orange: return UIColor(red: 0.95, green: 0.55, blue: 0.20, alpha: 1)
        case .pink:   return UIColor(red: 0.95, green: 0.40, blue: 0.55, alpha: 1)
        case .blue:   return UIColor(red: 0.35, green: 0.55, blue: 0.85, alpha: 1)
        }
    }

    // MARK: - 페이지 배경 (페이퍼 톤)

    private static func drawPageBackground(in rect: CGRect) {
        // v0.1: 흰색 유지. v0.2에서 paper tone(--paper) 적용 가능.
        UIColor.white.setFill()
        UIBezierPath(rect: rect).fill()
    }

    // MARK: - 저장

    private static func writeToFile(data: Data, suggestedName: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("exports", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // 파일명 sanitize
        let cleaned = suggestedName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let name = cleaned.isEmpty ? "Lumark-노트" : cleaned

        let url = dir.appendingPathComponent("\(name).pdf")
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw PDFExporterError.writeFailed(error)
        }
        return url
    }
}

private extension String {
    nonisolated var nonEmpty: String? { isEmpty ? nil : self }
}
