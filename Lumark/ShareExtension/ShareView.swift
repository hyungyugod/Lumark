//
//  ShareView.swift
//  Lumark / ShareExtension
//
//  Share Extension UI — spec §4 디자인:
//    - 받은 PDF/이미지 썸네일
//    - 색 매핑 미리보기 ("노랑=핵심 / 주황=주제")
//    - [변환 시작] 버튼
//
//  변환 시작 → App Group inbox에 stage → onConvert 콜백 (deeplink는 ViewController가).
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ShareView: View {
    let inputs: [ShareInput]
    let onConvert: (Result<[UUID], Error>) -> Void
    let onCancel: () -> Void

    @State private var isConverting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.cream.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: Space.s5)

                    // 헤더 텍스트
                    VStack(spacing: 4) {
                        Text("Lumark로 보내기")
                            .font(.system(size: 22, weight: .heavy, design: .serif))
                            .foregroundStyle(Palette.ink)

                        Text(summary)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.subtle)
                    }
                    .padding(.bottom, Space.s5)

                    // 썸네일
                    if !inputs.isEmpty {
                        thumbnailRow
                            .padding(.horizontal, Space.s5)
                            .padding(.bottom, Space.s5)
                    }

                    // 색 매핑 미리보기
                    colorMappingPreview
                        .padding(.horizontal, Space.s5)
                        .padding(.bottom, Space.s4)

                    Spacer()

                    // [변환 시작]
                    Button(action: convert) {
                        HStack(spacing: 8) {
                            if isConverting {
                                ProgressView().tint(Palette.cream)
                            }
                            Text(isConverting ? "보내는 중…" : "변환 시작")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Palette.cream)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .fill(Palette.brown)
                        )
                    }
                    .disabled(inputs.isEmpty || isConverting)
                    .opacity(inputs.isEmpty ? 0.5 : 1)
                    .padding(.horizontal, Space.s5)
                    .padding(.bottom, Space.s4)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소", action: onCancel)
                        .foregroundStyle(Palette.subtle)
                }
            }
            .alert("오류", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - 요약

    private var summary: String {
        if inputs.isEmpty {
            return "가져올 파일이 없어요"
        }
        let pdfs = inputs.filter { $0.isPDF }.count
        let imgs = inputs.count - pdfs
        var parts: [String] = []
        if pdfs > 0 { parts.append("PDF \(pdfs)개") }
        if imgs > 0 { parts.append("이미지 \(imgs)개") }
        return parts.joined(separator: " · ")
    }

    // MARK: - 썸네일

    private var thumbnailRow: some View {
        HStack(spacing: Space.s3) {
            ForEach(inputs.prefix(3)) { input in
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Palette.surface)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Palette.divider, lineWidth: 1)
                    Image(systemName: input.isPDF ? "doc.richtext" : "photo")
                        .font(.system(size: 28))
                        .foregroundStyle(Palette.brown)
                }
                .frame(width: 72, height: 92)
            }
            if inputs.count > 3 {
                Text("+\(inputs.count - 3)")
                    .font(Typo.mono)
                    .foregroundStyle(Palette.subtle)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 색 매핑 프리뷰

    private var colorMappingPreview: some View {
        HStack(spacing: Space.s2) {
            chip(color: .yellow, label: "노랑 = 핵심")
            chip(color: .orange, label: "주황 = 주제")
        }
        .padding(.horizontal, 4)
    }

    private func chip(color: ColorCategory, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color.swatch)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Palette.ink2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Palette.surface)
        )
        .overlay(
            Capsule().strokeBorder(Palette.divider, lineWidth: 1)
        )
    }

    // MARK: - 변환 (stage to App Group)

    private func convert() {
        guard !isConverting, !inputs.isEmpty else { return }
        isConverting = true

        Task {
            var ids: [UUID] = []
            do {
                for input in inputs {
                    let id = try await stage(input)
                    ids.append(id)
                }
                await MainActor.run {
                    isConverting = false
                    onConvert(.success(ids))
                }
            } catch {
                await MainActor.run {
                    isConverting = false
                    errorMessage = "받기 실패: \(error.localizedDescription)"
                    onConvert(.failure(error))
                }
            }
        }
    }

    private func stage(_ input: ShareInput) async throws -> UUID {
        // NSItemProvider → Data
        let typeIdentifier: String = input.isPDF
            ? UTType.pdf.identifier
            : UTType.image.identifier

        let item: NSSecureCoding = try await withCheckedThrowingContinuation { cont in
            input.provider.loadItem(forTypeIdentifier: typeIdentifier) { item, error in
                if let item { cont.resume(returning: item) }
                else { cont.resume(throwing: error ?? NSError(domain: "share", code: 1)) }
            }
        }

        let (data, filename) = try extractData(from: item, fallback: input.isPDF ? "공유받은.pdf" : "공유받은.jpg")

        return try AppGroup.stage(
            data: data,
            originalFilename: filename,
            isPDF: input.isPDF
        )
    }

    private func extractData(from item: NSSecureCoding, fallback: String) throws -> (Data, String) {
        if let url = item as? URL, let data = try? Data(contentsOf: url) {
            return (data, url.lastPathComponent)
        }
        if let data = item as? Data {
            return (data, fallback)
        }
        if let image = item as? UIImage, let data = image.jpegData(compressionQuality: 0.95) {
            return (data, fallback)
        }
        throw NSError(
            domain: "share", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "지원하지 않는 형식"]
        )
    }
}
