//
//  PageRenderer.swift
//  Lumark
//
//  spec §5 step 1: 입력(PDF/이미지)을 페이지별 UIImage 배열로 통일.
//
//  - PDF: PDFKit으로 페이지 분리 + 지정 DPI로 비트맵 렌더
//  - 단일 이미지: 그대로 [image] 반환 (1페이지짜리 노트)
//
//  형광펜 검출(S1) / OCR(S2)은 이 단계의 출력 UIImage를 입력으로 받음.
//  v0.1 디자인 단계에서는 PreviewView가 이 출력을 보여줄 수 있음.
//

import Foundation
import PDFKit
import UIKit
import UniformTypeIdentifiers

enum PageRendererError: Error, LocalizedError {
    case cannotOpenPDF(URL)
    case emptyPDF
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .cannotOpenPDF(let url): return "PDF를 열 수 없어요: \(url.lastPathComponent)"
        case .emptyPDF:               return "비어 있는 PDF예요"
        case .invalidImage:           return "이미지를 읽을 수 없어요"
        }
    }
}

/// PageRenderer 렌더 옵션.
/// 프로젝트 기본 isolation이 MainActor라서 명시적으로 nonisolated init 둠.
struct PageRenderOptions: Sendable {
    var dpi: CGFloat = 220
    var maxDimension: CGFloat = 4000
    var skipBlankPages: Bool = true

    nonisolated init(
        dpi: CGFloat = 220,
        maxDimension: CGFloat = 4000,
        skipBlankPages: Bool = true
    ) {
        self.dpi = dpi
        self.maxDimension = maxDimension
        self.skipBlankPages = skipBlankPages
    }
}

/// 렌더링은 메인쓰레드 블록하면 안 되므로 nonisolated.
/// (UIGraphicsImageRenderer/PDFKit은 thread-safe.)
nonisolated enum PageRenderer {

    /// 파일 URL의 UTI를 보고 PDF인지 이미지인지 판단해 적절히 렌더.
    /// `didIndex` 콜백: 페이지 1개 렌더 끝날 때마다 (현재페이지번호, 총페이지수) 호출.
    static func render(
        url: URL,
        options: PageRenderOptions = PageRenderOptions(),
        didIndex: ((Int, Int) -> Void)? = nil
    ) async throws -> [UIImage] {
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)
            ?? UTType(filenameExtension: url.pathExtension)
            ?? .data

        if type.conforms(to: .pdf) {
            return try await renderPDF(at: url, options: options, didIndex: didIndex)
        }
        if type.conforms(to: .image) {
            guard let img = UIImage(contentsOfFile: url.path) else {
                throw PageRendererError.invalidImage
            }
            didIndex?(1, 1)
            return [img]
        }
        // 알 수 없는 타입은 이미지로 시도
        if let img = UIImage(contentsOfFile: url.path) {
            didIndex?(1, 1)
            return [img]
        }
        throw PageRendererError.invalidImage
    }

    /// 이미지 데이터(메모리) 입력 — 카메라 / PhotosPicker 경로.
    static func render(imageData: Data) throws -> [UIImage] {
        guard let img = UIImage(data: imageData) else {
            throw PageRendererError.invalidImage
        }
        return [img]
    }

    // MARK: - PDF 렌더

    static func renderPDF(
        at url: URL,
        options: PageRenderOptions = PageRenderOptions(),
        didIndex: ((Int, Int) -> Void)? = nil
    ) async throws -> [UIImage] {
        guard let doc = PDFDocument(url: url) else {
            throw PageRendererError.cannotOpenPDF(url)
        }
        return try await renderPDFDocument(doc, options: options, didIndex: didIndex)
    }

    /// 메모리 PDF 데이터 → 렌더.
    static func renderPDF(
        data: Data,
        options: PageRenderOptions = PageRenderOptions(),
        didIndex: ((Int, Int) -> Void)? = nil
    ) async throws -> [UIImage] {
        guard let doc = PDFDocument(data: data) else {
            throw PageRendererError.emptyPDF
        }
        return try await renderPDFDocument(doc, options: options, didIndex: didIndex)
    }

    // MARK: - 내부

    private static func renderPDFDocument(
        _ doc: PDFDocument,
        options: PageRenderOptions,
        didIndex: ((Int, Int) -> Void)?
    ) async throws -> [UIImage] {
        let total = doc.pageCount
        guard total > 0 else { throw PageRendererError.emptyPDF }

        var out: [UIImage] = []
        out.reserveCapacity(total)

        for idx in 0..<total {
            // 명시적으로 Task.checkCancellation을 자주 — 긴 PDF 취소 응답성
            try Task.checkCancellation()

            guard let page = doc.page(at: idx) else { continue }
            let img = renderOne(page: page, options: options)

            if options.skipBlankPages, isBlank(img) {
                // 스킵하되 카운팅은 유지
            } else {
                out.append(img)
            }

            didIndex?(idx + 1, total)
        }

        return out
    }

    private static func renderOne(page: PDFPage, options: PageRenderOptions) -> UIImage {
        let bounds = page.bounds(for: .mediaBox)
        // PDF 좌표는 72dpi 기준. 원하는 dpi로 스케일.
        var scale: CGFloat = options.dpi / 72.0
        // 최대 변 제한
        let maxSide = max(bounds.width, bounds.height) * scale
        if maxSide > options.maxDimension {
            scale *= options.maxDimension / maxSide
        }

        let pixelSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1 // pixelSize 그대로
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)

        return renderer.image { ctx in
            // PDFKit page는 좌하단 원점. UIKit은 좌상단 원점. 뒤집기.
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: pixelSize))

            let c = ctx.cgContext
            c.translateBy(x: 0, y: pixelSize.height)
            c.scaleBy(x: 1, y: -1)
            c.scaleBy(x: scale, y: scale)

            page.draw(with: .mediaBox, to: c)
        }
    }

    /// 거의 흰색뿐인 페이지 감지 (간단 휴리스틱).
    /// v0.1: 평균 밝기 > 0.985면 빈 페이지로 간주.
    private static func isBlank(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return false }

        // 다운샘플링해서 빠르게 평가 — 32x32로 줄여서 평균
        let w = 32, h = 32
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var pixels = [UInt8](repeating: 0, count: w * h)

        guard let ctx = CGContext(
            data: &pixels,
            width: w, height: h,
            bitsPerComponent: 8,
            bytesPerRow: w,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return false }

        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        let total = pixels.reduce(0) { $0 + Int($1) }
        let avg = Double(total) / Double(w * h) / 255.0
        return avg > 0.985
    }
}
