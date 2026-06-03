//
//  HomeView.swift
//  Lumark
//
//  앱 진입 화면. 디자인: Lumark_design/HomeView.html.
//
//  v0.1 네비게이션 동선:
//    홈 ─ 업로드(PhotosPicker 다중 OR FileImporter) ─→ Processing ─→ Result
//    홈 ─ 카메라(DocumentScanner 다중 페이지)        ─→ Processing ─→ Result
//    홈 ─ 최근 작업 row 탭                          ─→ Result(해당 Note)
//    홈 ─ 설정 / 톱니 버튼                           ─→ Settings (sheet)
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import PDFKit

// HomeRoute / JobSource / PendingJob 는 App/AppRouting.swift 로 이동

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @State private var auth = AuthManager.shared
    @State private var ocrPrefs = OCRPreferences.shared

    // 네비게이션
    @State private var path: [HomeRoute] = []
    @State private var jobs: [UUID: PendingJob] = [:]
    @State private var resultsCache: [UUID: Note] = [:]
    /// 방금 만든 노트에 대한 1회성 안내(예: 부분 실패). noteID로 ResultView에 전달.
    @State private var pendingNotice: [UUID: String] = [:]

    // 시트
    @State private var showingSettings = false
    @State private var showingOnboarding = !UserDefaults.standard.hasOnboarded
    @State private var showingSignIn = false
    // 미로그인 상태에서 Lumark Cloud 변환을 시도하면, 로그인/오프라인/취소를 묻고
    // 잡 파라미터를 잠시 보관했다 선택에 따라 이어간다.
    @State private var showingCloudChoice = false
    @State private var pendingCloudJob: (filename: String, totalPages: Int, source: JobSource, inboxID: UUID?)?

    // 업로드 소스 선택
    @State private var showingUploadMenu = false
    @State private var showingPhotosPicker = false
    @State private var showingFileImporter = false

    // 카메라
    @State private var showingScanner = false

    // PhotosPicker — 다중 선택
    @State private var photoItems: [PhotosPickerItem] = []
    /// 한 번에 변환 가능한 최대 페이지 수.
    /// OCR이 외부 API(Gemini 등)일 때 토큰 비용 상한 보장 — 무료 배포라 개발자 자비 부담.
    private let maxPagesPerConversion = 20

    // 에러
    @State private var activeError: LumarkError?
    @State private var pendingLargeFile: (url: URL, pages: Int, sizeMB: Double)?

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Palette.cream.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                            .padding(.horizontal, Space.s5)
                            .padding(.top, Space.s4)
                            .padding(.bottom, Space.s3)

                        VStack(alignment: .leading, spacing: 0) {
                            actionGrid
                                .padding(.top, Space.s2)

                            HintBanner()
                                .padding(.top, 18)

                            if notes.isEmpty {
                                EmptyStateView()
                                    .padding(.top, Space.s4)
                            } else {
                                sectionHeader
                                    .padding(.top, 28)
                                    .padding(.bottom, Space.s3)
                                recentList
                            }
                        }
                        .padding(.horizontal, Space.s5)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: HomeRoute.self) { route in
                destination(for: route)
            }
            // SettingsView에서 "처음 안내 다시 보기"를 누르면 UserDefaults 플래그가
            // false로 리셋된 채로 dismiss된다. dismiss가 끝난 뒤(onDismiss) onboarding을
            // 띄운다. dismiss와 동시에 present하면 같은 뷰의 두 sheet가 충돌해 누락된다.
            .sheet(isPresented: $showingSettings, onDismiss: {
                if !UserDefaults.standard.hasOnboarded {
                    showingOnboarding = true
                }
            }) {
                SettingsView()
            }
            .sheet(isPresented: $showingOnboarding) {
                OnboardingSheet { showingOnboarding = false }
            }
            .sheet(isPresented: $showingSignIn, onDismiss: {
                // 로그인 안 하고 닫았으면 보관한 잡 정리.
                if !auth.isSignedIn { discardPendingCloudJob() }
            }) {
                SignInView(onSignedIn: {
                    showingSignIn = false
                    resumePendingCloudJob()
                })
            }
            .confirmationDialog(
                "Lumark Cloud는 로그인이 필요해요",
                isPresented: $showingCloudChoice,
                titleVisibility: .visible
            ) {
                Button("Apple로 로그인하고 만들기") { showingSignIn = true }
                Button("오프라인으로 변환 (로그인 없이)") { convertOfflineFromPending() }
                Button("취소", role: .cancel) {
                    discardPendingCloudJob()
                }
            } message: {
                Text("로그인하면 매달 무료 크레딧으로 더 정확하게 변환해요. 또는 로그인 없이 이 기기에서 바로 변환할 수 있어요(Apple Vision · 오프라인).")
            }
            .confirmationDialog("업로드", isPresented: $showingUploadMenu, titleVisibility: .visible) {
                Button("사진 라이브러리에서") { showingPhotosPicker = true }
                Button("파일에서 (PDF·이미지)") { showingFileImporter = true }
                Button("취소", role: .cancel) {}
            } message: {
                Text("어디서 가져올까요?")
            }
            .photosPicker(
                isPresented: $showingPhotosPicker,
                selection: $photoItems,
                maxSelectionCount: maxPagesPerConversion,
                selectionBehavior: .ordered,
                matching: .images,
                photoLibrary: .shared()
            )
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .errorAlert(error: $activeError) { action in
                handleErrorAction(action)
            }
            .fullScreenCover(isPresented: $showingScanner) {
                DocumentScannerView(
                    onScanned: { images in
                        showingScanner = false
                        ingestScannedImages(images)
                    },
                    onCancel: { showingScanner = false },
                    onError: { error in
                        showingScanner = false
                        activeError = .wrapped(code: "CAM", message: error.localizedDescription)
                    }
                )
                .ignoresSafeArea()
            }
            .onChange(of: photoItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task { await loadPickedItems(newItems) }
            }
            .onChange(of: router.pendingDeeplink) { _, deeplink in
                if let dl = deeplink {
                    handleDeeplink(dl)
                    router.pendingDeeplink = nil
                }
            }
            .task {
                // 앱 콜드 스타트로 deeplink가 먼저 도착했을 수 있음
                if let dl = router.pendingDeeplink {
                    handleDeeplink(dl)
                    router.pendingDeeplink = nil
                }
                // 중단된(미완료) 작업은 폐기하고 임시 파일도 함께 정리
                discardInterruptedJobs()
                // 크레딧 잔액 펠 채우기 (Lumark Cloud + 로그인 시)
                if ocrPrefs.engine == .lumarkCloud, auth.isSignedIn {
                    await auth.refreshCredits()
                    await auth.refreshGlobalUsage()
                }
            }
        }
    }

    // MARK: - 네비게이션 destination

    @ViewBuilder
    private func destination(for route: HomeRoute) -> some View {
        switch route {
        case .processing(let jobID):
            if let job = jobs[jobID] {
                ProcessingView(
                    totalPages: job.totalPages,
                    filename: job.filename,
                    jobID: jobID,
                    source: job.source,
                    onCancel: {
                        finalizeJob(jobID, success: false)
                        path.removeAll()
                    },
                    onFinish: { note, failedPages in
                        finalizeJob(jobID, success: true)
                        openFreshResult(note, failedPages: failedPages)
                    }
                )
            } else {
                missingJobFallback
            }

        case .result(let noteID):
            if let note = resolvedNote(for: noteID) {
                ResultView(
                    note: note,
                    onClose: { path.removeAll() },
                    onDeleted: { id in
                        resultsCache.removeValue(forKey: id)
                        pendingNotice.removeValue(forKey: id)
                    },
                    initialNotice: pendingNotice[noteID]
                )
            } else {
                missingJobFallback
            }

        case .recentList:
            RecentNotesView(
                onOpenNote: { note in openExistingNote(note) },
                onDeleted: { id in resultsCache.removeValue(forKey: id) }
            )

        case .myQuizzes:
            MyQuizzesView { note in
                openExistingNote(note)
            }
        }
    }

    /// 잡 종료 시 공통 정리: JobStateStore에서 제거 + Share Extension inbox 정리.
    /// `JobStateStore.finish`의 단일 호출 지점을 view layer로 통일한다.
    /// (ProcessingViewModel은 진행 상태 update만 담당, lifecycle 종료는 view가 결정.)
    private func finalizeJob(_ jobID: UUID, success: Bool) {
        if let job = jobs[jobID] {
            cleanupTemporarySource(job.source, inboxID: job.inboxID)
            cleanupJobCache(jobID: jobID)
        }
        JobStateStore.shared.finish(id: jobID)
        jobs.removeValue(forKey: jobID)
        _ = success // (현재는 분기 동일, 향후 telemetry 등을 위한 자리)
    }

    private var missingJobFallback: some View {
        VStack(spacing: Space.s3) {
            Text("연결이 끊겼어요")
                .font(Typo.h2)
                .foregroundStyle(Palette.ink)
            Button("홈으로") { path.removeAll() }
                .foregroundStyle(Palette.brown)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.cream)
    }

    /// 캐시에 있으면 그쪽, 없으면 SwiftData에서 Note.id로 검색.
    private func resolvedNote(for id: UUID) -> Note? {
        if let cached = resultsCache[id] { return cached }
        return notes.first { $0.id == id }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                LumarkWordmark(size: 30)

                Text("형광펜만 그으면,\n정리 노트가 알아서 쌓여요")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.subtle)
                    .lineSpacing(2)
            }

            Spacer()

            creditPill

            Button {
                showingOnboarding = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Palette.brown)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("사용 설명서 다시 보기")

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Palette.ink2)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("설정")
        }
    }

    /// 크레딧 잔액 펠 — Lumark Cloud 엔진 + 로그인 + 잔액 조회됨일 때만. 탭하면 설정.
    @ViewBuilder
    private var creditPill: some View {
        if ocrPrefs.engine == .lumarkCloud, auth.isSignedIn, let c = auth.credits {
            Button {
                showingSettings = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 11))
                    Text("\(c)")
                        .font(.system(size: 13, weight: .semibold))
                    if let g = auth.globalRemaining {
                        Text("· 전체 \(g)")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.subtle)
                    }
                }
                .foregroundStyle(Palette.brown)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Palette.Highlight.yellowBG))
                .overlay(Capsule().strokeBorder(Palette.Highlight.yellowEdge, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            .accessibilityLabel("남은 크레딧 \(c)개")
            .accessibilityHint("탭하면 계정 설정")
        }
    }

    // MARK: 2x2 Action grid

    private var actionGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            // 업로드 — 사진 / 파일 분기
            ActionCard(
                systemImage: "arrow.up.to.line",
                label: "업로드",
                desc: "PDF·이미지 선택\n1페이지당 1크레딧",
                primary: true
            ) {
                showingUploadMenu = true
            }

            ActionCard(
                systemImage: "camera",
                label: "카메라",
                desc: "직접 촬영",
                primary: true
            ) {
                openCamera()
            }

            ActionCard(
                systemImage: "doc.text",
                label: "최근 작업",
                desc: "내 정리본"
            ) {
                path.append(.recentList)
            }

            ActionCard(
                systemImage: "rectangle.stack",
                label: "내 퀴즈",
                desc: "만든 카드 학습"
            ) {
                path.append(.myQuizzes)
            }
        }
    }

    // MARK: Recent

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("최근 작업")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(Palette.ink)
            Spacer()
            Button {
                path.append(.recentList)
            } label: {
                HStack(spacing: 2) {
                    Text("모두 보기")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Palette.brown)
            }
        }
    }

    private var recentList: some View {
        VStack(spacing: 10) {
            ForEach(notes.prefix(3)) { note in
                Button {
                    openExistingNote(note)
                } label: {
                    RecentNoteRow(note: note)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 액션

    /// 새로 변환된 노트를 결과 화면에서 보여준다.
    /// 처리 중인 노트가 path에 있을 때 호출 — path를 통째로 replace해서
    /// back 누르면 홈으로 가게 함.
    private func openFreshResult(_ note: Note, failedPages: Int = 0) {
        persistFreshNote(note)
        resultsCache[note.id] = note
        if failedPages > 0 {
            pendingNotice[note.id] = "\(failedPages)페이지는 일시적인 오류로 못 읽었어요. 다시 변환하면 채워질 수 있어요."
        }
        path = [.result(noteID: note.id)]
    }

    /// Lumark의 핵심 약속은 "변환하면 정리본이 자동으로 쌓임"이다.
    /// 결과 화면 캐시에만 두면 앱 재실행/최근 작업에서 사라지므로 완료 시 즉시 저장한다.
    private func persistFreshNote(_ note: Note) {
        guard !notes.contains(where: { $0.id == note.id }) else { return }
        modelContext.insert(note)
        do {
            try modelContext.save()
        } catch {
            activeError = .wrapped(code: "SAVE", message: "정리본 저장 실패: \(error.localizedDescription)")
        }
    }

    /// 기존 노트를 결과 화면에 push. RecentNotes에서 호출되면 path에 append돼서
    /// back으로 RecentNotes 화면으로 돌아갈 수 있게.
    private func openExistingNote(_ note: Note) {
        resultsCache[note.id] = note
        path.append(.result(noteID: note.id))
    }

    // MARK: Picker handler

    /// 다중 선택된 사진들을 순차로 로드. 선택 순서대로 페이지가 됨.
    /// 모두 실패하면 에러, 일부만 실패하면 성공한 것들로 진행 (부분 성공 — spec §8).
    private func loadPickedItems(_ items: [PhotosPickerItem]) async {
        var loaded: [Data] = []
        loaded.reserveCapacity(items.count)
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                loaded.append(data)
            }
        }
        await MainActor.run {
            guard !loaded.isEmpty else {
                self.activeError = .wrapped(code: "PHOTO-LOAD", message: "사진을 불러올 수 없어요.")
                self.photoItems = []
                return
            }
            startProcessing(
                filename: photoFilename(count: loaded.count),
                totalPages: loaded.count,
                source: .images(loaded)
            )
            self.photoItems = [] // 다음 선택 위해 리셋
        }
    }

    /// 선택한 사진 N장에 붙일 표시용 파일명.
    private func photoFilename(count: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 HH:mm"
        let ts = f.string(from: .now)
        return count == 1 ? "사진 \(ts)" : "사진 \(ts) (\(count)장)"
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            ingestFile(at: url)
        case .failure:
            activeError = .pdfCorrupted
        }
    }

    /// 파일을 받아 source/pageCount 결정 후 processing으로 진입.
    /// spec §8: 입력 너무 큼(>50MB or >100p) 시 확인 다이얼로그.
    private func ingestFile(at url: URL) {
        // file:// security scoped access — Files / iCloud Drive에서 받은 URL은 권한 범위 시작 필요
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            guard let doc = PDFDocument(url: url) else {
                activeError = .pdfCorrupted
                return
            }
            let pages = doc.pageCount
            guard pages > 0 else {
                activeError = .allPagesBlank
                return
            }

            // 20장 상한 — 외부 OCR 토큰 비용 보호
            if pages > maxPagesPerConversion {
                activeError = .wrapped(
                    code: "PAGE-LIMIT",
                    message: "한 번에 최대 \(maxPagesPerConversion)페이지까지 변환할 수 있어요. PDF를 나눠서 올려주세요. (현재 \(pages)페이지)"
                )
                return
            }

            // 크기 체크
            let sizeMB = fileSizeMB(at: url)
            if (sizeMB ?? 0) > 50 {
                // 사용자 확인이 필요 — pendingLargeFile 보관 후 alert로 진행 여부 물음
                do {
                    let staged = try stage(url: url)
                    pendingLargeFile = (staged, pages, sizeMB ?? 0)
                    activeError = .inputTooLarge(sizeMB: sizeMB, pages: pages)
                } catch {
                    activeError = .wrapped(code: "FS-COPY", message: error.localizedDescription)
                }
                return
            }

            // PDF는 임시 위치로 복사해두고 (스코프 풀린 후에도 접근 가능하도록)
            do {
                let staged = try stage(url: url)
                startProcessing(
                    filename: url.lastPathComponent,
                    totalPages: pages,
                    source: .pdf(staged)
                )
            } catch {
                activeError = .wrapped(code: "FS-COPY", message: error.localizedDescription)
            }
        } else {
            // 이미지로 시도
            guard let data = try? Data(contentsOf: url) else {
                activeError = .wrapped(code: "IMG-READ", message: "이미지를 읽을 수 없어요.")
                return
            }
            startProcessing(
                filename: url.lastPathComponent,
                totalPages: 1,
                source: .images([data])
            )
        }
    }

    private func fileSizeMB(at url: URL) -> Double? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let bytes = values.fileSize else { return nil }
        return Double(bytes) / 1_000_000
    }

    // MARK: - 카메라

    private func openCamera() {
        Task {
            let status = await PermissionService.requestCamera()
            await MainActor.run {
                switch status {
                case .authorized:
                    showingScanner = true
                case .denied, .restricted:
                    activeError = .cameraPermissionDenied
                case .undetermined:
                    // 요청 후에도 undetermined면 거부로 간주
                    activeError = .cameraPermissionDenied
                }
            }
        }
    }

    private func ingestScannedImages(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        // 스캔 결과 N장을 모두 페이지로. 인코딩 실패한 이미지는 스킵 (부분 성공).
        var datas = images.compactMap { $0.jpegData(compressionQuality: 0.9) }
        guard !datas.isEmpty else {
            activeError = .wrapped(code: "CAM-ENCODE", message: "촬영 결과를 인코딩할 수 없어요.")
            return
        }
        // 20장 상한 — 외부 OCR 토큰 비용 보호
        if datas.count > maxPagesPerConversion {
            datas = Array(datas.prefix(maxPagesPerConversion))
        }
        let ts = scanTimestamp()
        let filename = datas.count == 1 ? "스캔 \(ts).jpg" : "스캔 \(ts) (\(datas.count)장)"
        startProcessing(
            filename: filename,
            totalPages: datas.count,
            source: .images(datas)
        )
    }

    private func scanTimestamp() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 HH:mm"
        return f.string(from: .now)
    }

    /// 외부 URL을 앱 임시 디렉토리로 복사 — security-scoped 만료 후에도 접근 가능.
    private func stage(url: URL) throws -> URL {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let dest = tmpDir.appendingPathComponent("\(UUID().uuidString).pdf")
        try FileManager.default.copyItem(at: url, to: dest)
        return dest
    }

    private func startProcessing(
        filename: String,
        totalPages: Int,
        source: JobSource,
        inboxID: UUID? = nil
    ) {
        // Lumark Cloud 경로만 로그인 + 크레딧 사전 체크. (본인 키·Apple Vision은 바로 진행)
        guard OCRPreferences.shared.engine == .lumarkCloud else {
            beginJob(filename: filename, totalPages: totalPages, source: source, inboxID: inboxID)
            return
        }
        // 로그인 게이트 — 페이지 렌더 전에. 미로그인이면 로그인/오프라인/취소를 묻는다.
        guard AuthManager.shared.isSignedIn else {
            pendingCloudJob = (filename, totalPages, source, inboxID)
            showingCloudChoice = true
            return
        }
        // 크레딧 사전 체크 — 잔액을 새로고침한 뒤 페이지 수만큼 있는지 확인.
        // (부족한데 시작하면 일부 페이지만 처리되고 도중에 402로 깨짐)
        Task {
            await AuthManager.shared.refreshCredits()
            if let c = AuthManager.shared.credits, c < totalPages {
                cleanupTemporarySource(source, inboxID: inboxID)
                activeError = .wrapped(
                    code: "CREDITS",
                    message: "이 정리본은 약 \(totalPages)크레딧이 필요한데 지금 \(c)개 남았어요. 다음 달에 충전되거나, 설정 → OCR 엔진에서 '내 Gemini 키'로 바꾸면 Lumark 크레딧 없이 쓸 수 있어요."
                )
            } else {
                beginJob(filename: filename, totalPages: totalPages, source: source, inboxID: inboxID)
            }
        }
    }

    /// "오프라인으로 변환" 선택 — 엔진을 Apple Vision으로 바꾸고 보관한 잡을 바로 진행.
    private func convertOfflineFromPending() {
        guard let j = pendingCloudJob else { return }
        pendingCloudJob = nil
        ocrPrefs.engine = .appleVision
        beginJob(filename: j.filename, totalPages: j.totalPages, source: j.source, inboxID: j.inboxID)
    }

    /// 로그인 성공 후 보관한 Cloud 잡을 이어서 시작(이번엔 게이트 통과).
    private func resumePendingCloudJob() {
        guard auth.isSignedIn, let j = pendingCloudJob else { return }
        pendingCloudJob = nil
        startProcessing(filename: j.filename, totalPages: j.totalPages, source: j.source, inboxID: j.inboxID)
    }

    private func discardPendingCloudJob() {
        guard let job = pendingCloudJob else { return }
        cleanupTemporarySource(job.source, inboxID: job.inboxID)
        pendingCloudJob = nil
    }

    /// 실제 잡 등록 + 영속화 + 처리 화면 진입. (게이트는 startProcessing에서 끝냄)
    private func beginJob(
        filename: String,
        totalPages: Int,
        source: JobSource,
        inboxID: UUID? = nil
    ) {
        let id = UUID()
        let job = PendingJob(
            id: id,
            filename: filename,
            totalPages: totalPages,
            source: source,
            inboxID: inboxID
        )
        jobs[id] = job

        // 영속화: 백그라운드/콜드 재시작 대비
        let stagedURL: URL?
        let imageDataPaths: [String]?
        let isPDF: Bool
        switch source {
        case .pdf(let url):
            stagedURL = url
            imageDataPaths = nil
            isPDF = true
        case .images(let datas):
            stagedURL = nil
            // 이미지 N장을 디스크에 페이지 순서로 저장해 재개 가능하게.
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("jobs", isDirectory: true)
                .appendingPathComponent(id.uuidString, isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            var paths: [String] = []
            for (idx, data) in datas.enumerated() {
                let path = dir.appendingPathComponent(String(format: "p%04d.img", idx))
                try? data.write(to: path, options: .atomic)
                paths.append(path.path)
            }
            imageDataPaths = paths
            isPDF = false
        }
        JobStateStore.shared.register(JobState(
            id: id,
            filename: filename,
            totalPages: totalPages,
            stagedURL: stagedURL,
            imageDataPaths: imageDataPaths,
            isPDF: isPDF,
            inboxID: inboxID
        ))

        path = [.processing(jobID: id)]
    }

    // MARK: - Deeplink (Share Extension 진입)

    /// 콜드 부팅 시 중단된(미완료) 작업을 정리한다.
    /// v1.0은 자동 재개를 하지 않는다 — 재개가 사실상 전체 재처리라, Lumark Cloud로
    /// 변환 중이었다면 이미 처리한 페이지의 크레딧이 다시 차감될 수 있기 때문.
    /// 중단된 변환은 깔끔히 폐기하고, Share Extension inbox·임시 파일도 함께 정리한다.
    /// (사용자는 홈에서 다시 변환하면 된다.)
    private func discardInterruptedJobs() {
        let interrupted = JobStateStore.shared.jobs
        for job in interrupted {
            if let inboxID = job.inboxID {
                AppGroup.cleanup(id: inboxID)
            } else if let stagedURL = job.stagedURL {
                removeTemporaryFile(at: stagedURL)
            }
            // 이미지 변환용 임시 디렉토리(jobs/{id}/) 정리.
            cleanupJobCache(jobID: job.id)
            JobStateStore.shared.finish(id: job.id)
        }
    }

    private func cleanupTemporarySource(_ source: JobSource, inboxID: UUID?) {
        if let inboxID {
            AppGroup.cleanup(id: inboxID)
            return
        }
        if case .pdf(let url) = source {
            removeTemporaryFile(at: url)
        }
    }

    private func cleanupJobCache(jobID: UUID) {
        let jobDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("jobs", isDirectory: true)
            .appendingPathComponent(jobID.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: jobDir)
    }

    private func removeTemporaryFile(at url: URL) {
        let tmpPath = FileManager.default.temporaryDirectory.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(tmpPath) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func handleDeeplink(_ deeplink: LumarkDeeplink) {
        switch deeplink {
        case .importInbox(let id):
            ingestInbox(id: id)
        }
    }

    /// App Group inbox에서 stage된 파일을 메인 앱으로 가져와 ProcessingView 진입.
    private func ingestInbox(id: UUID) {
        do {
            let (meta, dataURLs) = try AppGroup.load(id: id)

            let pageCount: Int
            let source: JobSource
            if meta.utiHint == "pdf" {
                guard let pdfURL = dataURLs.first,
                      let doc = PDFDocument(url: pdfURL), doc.pageCount > 0 else {
                    activeError = .pdfCorrupted
                    AppGroup.cleanup(id: id)
                    return
                }
                guard doc.pageCount <= maxPagesPerConversion else {
                    activeError = .wrapped(
                        code: "PAGE-LIMIT",
                        message: "한 번에 최대 \(maxPagesPerConversion)페이지까지 변환할 수 있어요. (현재 \(doc.pageCount)페이지)"
                    )
                    AppGroup.cleanup(id: id)
                    return
                }
                pageCount = doc.pageCount
                source = .pdf(pdfURL)
            } else {
                let datas = dataURLs.compactMap { try? Data(contentsOf: $0) }
                guard !datas.isEmpty else {
                    activeError = .wrapped(code: "IMG-READ", message: "이미지를 읽을 수 없어요.")
                    AppGroup.cleanup(id: id)
                    return
                }
                guard datas.count <= maxPagesPerConversion else {
                    activeError = .wrapped(
                        code: "PAGE-LIMIT",
                        message: "한 번에 최대 \(maxPagesPerConversion)페이지까지 변환할 수 있어요. (현재 \(datas.count)페이지)"
                    )
                    AppGroup.cleanup(id: id)
                    return
                }
                pageCount = datas.count
                source = .images(datas)
            }

            // inboxID를 PendingJob에 묶어두고 cleanup은 processing 완료/취소 시점에.
            // (finalizeJob에서 AppGroup.cleanup 호출)
            startProcessing(
                filename: meta.originalFilename,
                totalPages: pageCount,
                source: source,
                inboxID: id
            )
        } catch {
            activeError = .wrapped(code: "INBOX-LOAD", message: error.localizedDescription)
        }
    }

    // MARK: - Error Action Handler

    private func handleErrorAction(_ action: ErrorAction) {
        switch action {
        case .proceed:
            // inputTooLarge에서 사용자가 "계속" 누름 → 보관해둔 파일로 진행
            if let big = pendingLargeFile {
                pendingLargeFile = nil
                startProcessing(
                    filename: big.url.lastPathComponent,
                    totalPages: big.pages,
                    source: .pdf(big.url)
                )
            }
        case .cancel, .dismiss:
            if let big = pendingLargeFile {
                removeTemporaryFile(at: big.url)
            }
            pendingLargeFile = nil
        case .openSystemSettings:
            PermissionService.openSystemSettings()
        case .openSettings:
            showingSettings = true
        case .tryAnotherFile:
            showingFileImporter = true
        case .retry:
            // 컨텍스트에 따라 다름 — 현재는 단순히 닫기
            break
        case .viewResult:
            break
        case .switchToOwnKey:
            // 엔진 전환은 errorAlert 모디파이어가 공통 처리. 여기선 추가 동작 없음.
            break
        }
    }
}

// ActionCardContent는 Views/Components/ActionCardContent.swift 로 이동

#Preview("Empty") {
    HomeView()
        .environment(AppRouter())
        .modelContainer(for: [Note.self, Page.self, Highlight.self], inMemory: true)
}

#Preview("With recent") {
    HomeView()
        .environment(AppRouter())
        .modelContainer(MockData.previewContainer(withMockNotes: true))
}
