//
//  DetectionOverlayView.swift
//  Lumark
//
//  ResultView "원본" 탭에서 실제 파이프라인 결과 페이지를 보여주는 컴포넌트.
//
//  - 한 페이지에 대해: 저장된 imageData를 UIImage로 디코드해 표시.
//  - DebugPreferences.showDetectionOverlay가 ON이면 Highlight.boundingBoxData를
//    decode해 색별 외곽선을 위에 덧그린다 — Day 2~4 HSV 튜닝용 시각화.
//
//  Mock 노트(imageData 비어있음)는 PDFFauxView가 처리하므로 여기는 데이터가
//  있는 경우만 다룬다.
//

import SwiftUI
import UIKit
import CoreGraphics

struct DetectionOverlayView: View {
    let note: Note
    var showOverlay: Bool = false

    var body: some View {
        VStack(spacing: Space.s4) {
            ForEach(orderedPages, id: \.id) { page in
                PageImageCard(page: page, showOverlay: showOverlay)
            }
        }
    }

    private var orderedPages: [Page] {
        note.pages.sorted { $0.pageNumber < $1.pageNumber }
    }
}

// MARK: - 한 페이지 카드

private struct PageImageCard: View {
    let page: Page
    let showOverlay: Bool

    var body: some View {
        // 디코드는 view body마다 매번 하지 말고 lazy로. UIImage(data:)는 가벼우니
        // 한 페이지 단위에선 OK — 실제로 화면에 보일 때만 실행되는 ForEach 자식.
        let image = UIImage(data: page.imageData)

        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)

                    if showOverlay, img.size.width > 0, img.size.height > 0 {
                        GeometryReader { geo in
                            overlayCanvas(image: img, displaySize: geo.size)
                        }
                        .aspectRatio(img.size, contentMode: .fit)
                    }
                } else {
                    placeholder
                }
            }

            HStack {
                Spacer()
                Text("p. \(page.pageNumber)")
                    .font(Typo.monoSm)
                    .foregroundStyle(Palette.muted)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(Palette.divider, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 30, x: 0, y: 14)
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Palette.surface2)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                    Text("페이지 이미지 없음")
                        .font(.system(size: 12))
                }
                .foregroundStyle(Palette.muted)
            }
    }

    /// 검출 bbox를 색별 외곽선으로 그린다. bbox는 원본 픽셀 좌표 → display 좌표로 스케일.
    @ViewBuilder
    private func overlayCanvas(image: UIImage, displaySize: CGSize) -> some View {
        let scaleX = displaySize.width / image.size.width
        let scaleY = displaySize.height / image.size.height

        Canvas { ctx, _ in
            for h in page.highlights {
                guard let rect = decodeRect(h.boundingBoxData) else { continue }
                let scaled = CGRect(
                    x: rect.minX * scaleX,
                    y: rect.minY * scaleY,
                    width: rect.width * scaleX,
                    height: rect.height * scaleY
                )
                let path = Path(roundedRect: scaled, cornerRadius: 2)
                // 외곽선
                ctx.stroke(path, with: .color(h.colorCategory.swatch), lineWidth: 2)
                // 살짝 채움 — overlay임을 강조
                ctx.fill(path, with: .color(h.colorCategory.swatch.opacity(0.18)))
            }
        }
    }

    /// boundingBoxData는 `withUnsafeBytes(of: CGRect)`로 인코딩됨.
    /// MemoryLayout<CGRect>.size 와 길이 안 맞으면 nil.
    private func decodeRect(_ data: Data) -> CGRect? {
        guard data.count == MemoryLayout<CGRect>.size else { return nil }
        return data.withUnsafeBytes { $0.load(as: CGRect.self) }
    }
}
