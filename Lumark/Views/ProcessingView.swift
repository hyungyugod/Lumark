//
//  ProcessingView.swift
//  Lumark
//
//  변환 진행 화면. spec §2 명세 + §5 파이프라인.
//
//  구성:
//    - 헤더: 파일명 (또는 "변환 중")
//    - 단계 인디케이터 4개 (페이지 분리 / 검출 / OCR / 조립)
//    - 전체 진행률 바
//    - 현재 페이지 표시 (OCR 단계만)
//    - [취소] 버튼
//

import SwiftUI

struct ProcessingView: View {
    @State private var vm: ProcessingViewModel
    var filename: String
    var jobID: UUID?
    var onCancel: () -> Void
    var onFinish: (Note) -> Void

    init(
        totalPages: Int,
        filename: String,
        jobID: UUID? = nil,
        source: JobSource? = nil,
        onCancel: @escaping () -> Void,
        onFinish: @escaping (Note) -> Void
    ) {
        // 재개 가능한 잡이면 마지막 진행 상태를 복원해 vm에 주입.
        let resume = jobID.flatMap { id in
            JobStateStore.shared.jobs.first { $0.id == id }
        }
        self._vm = State(initialValue: ProcessingViewModel(
            totalPages: totalPages,
            source: source,
            jobID: jobID,
            resumeFrom: resume
        ))
        self.filename = filename
        self.jobID = jobID
        self.onCancel = onCancel
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // 상단 라벨
                VStack(spacing: Space.s2) {
                    Text("변환 중")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(Palette.brass)

                    Text(filename)
                        .font(.system(size: 22, weight: .heavy, design: .serif))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)

                    Text(progressDescription)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.subtle)
                }
                .padding(.bottom, Space.s7)

                // 단계 인디케이터
                stageList
                    .padding(.horizontal, Space.s5)
                    .padding(.bottom, Space.s7)

                // 진행률 바
                progressBar
                    .padding(.horizontal, Space.s5)
                    .padding(.bottom, Space.s4)

                Text(percentLabel)
                    .font(Typo.mono)
                    .foregroundStyle(Palette.muted)

                Spacer(minLength: 0)

                // 취소
                Button {
                    vm.cancel()
                    onCancel()
                } label: {
                    Text("취소")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .fill(Palette.surface2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .strokeBorder(Palette.hairline, lineWidth: 1)
                        )
                }
                .padding(.horizontal, Space.s5)
                .padding(.bottom, Space.s6)
            }
        }
        .navigationBarHidden(true)
        .task {
            vm.start()
        }
        .onChange(of: vm.phase) { _, newPhase in
            if newPhase == .finished, let note = vm.resultNote {
                onFinish(note)
            }
        }
    }

    // MARK: - 단계 리스트

    private var stageList: some View {
        VStack(spacing: 14) {
            ForEach(ProcessingViewModel.Stage.allCases) { stage in
                stageRow(stage)
            }
        }
    }

    private func stageRow(_ stage: ProcessingViewModel.Stage) -> some View {
        let state = stageState(stage)

        return HStack(spacing: Space.s3) {
            ZStack {
                Circle()
                    .fill(circleFill(state))
                    .frame(width: 28, height: 28)
                Circle()
                    .strokeBorder(circleEdge(state), lineWidth: 1)
                    .frame(width: 28, height: 28)

                if state == .done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.cream)
                } else if state == .active {
                    Image(systemName: stage.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.brown)
                } else {
                    Image(systemName: stage.icon)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Palette.muted)
                }
            }

            Text(stage.label)
                .font(.system(size: 14.5, weight: state == .pending ? .regular : .semibold))
                .foregroundStyle(state == .pending ? Palette.muted : Palette.ink)

            Spacer()

            if state == .active {
                ProgressView()
                    .controlSize(.small)
                    .tint(Palette.brown)
            }
        }
    }

    private enum StageState { case done, active, pending }

    private func stageState(_ stage: ProcessingViewModel.Stage) -> StageState {
        if vm.phase == .finished { return .done }
        if stage.rawValue < vm.currentStage.rawValue { return .done }
        if stage == vm.currentStage { return .active }
        return .pending
    }

    private func circleFill(_ state: StageState) -> Color {
        switch state {
        case .done:    return Palette.brown
        case .active:  return Palette.Highlight.yellowBG
        case .pending: return Palette.surface2
        }
    }

    private func circleEdge(_ state: StageState) -> Color {
        switch state {
        case .done:    return Palette.brown2
        case .active:  return Palette.Highlight.yellowEdge
        case .pending: return Palette.hairline
        }
    }

    // MARK: - 진행률

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.divider)
                Capsule()
                    .fill(Palette.brown)
                    .frame(width: max(0, geo.size.width * vm.overallProgress))
                    .animation(.easeInOut(duration: 0.25), value: vm.overallProgress)
            }
        }
        .frame(height: 4)
    }

    private var progressDescription: String {
        switch vm.phase {
        case .idle, .running:
            if vm.currentStage == .ocr {
                return "\(vm.currentPage)/\(vm.totalPages) 페이지 OCR 중"
            }
            return vm.currentStage.label
        case .cancelled: return "취소됨"
        case .finished:  return "완료"
        }
    }

    private var percentLabel: String {
        "\(Int(vm.overallProgress * 100))%"
    }
}

#Preview {
    ProcessingView(
        totalPages: 4,
        filename: "항생제정리.pdf",
        onCancel: {},
        onFinish: { _ in }
    )
}
