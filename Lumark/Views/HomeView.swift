//
//  HomeView.swift
//  Lumark
//
//  앱 진입 화면. 디자인: Lumark_design/HomeView.html.
//
//  v0.1 디자인 단계의 네비게이션 동선:
//    홈 ─ 업로드(PhotosPicker) ─→ Processing(Mock) ─→ Result(Mock note)
//    홈 ─ 최근 작업 row 탭     ─→ Result(해당 Note)
//    홈 ─ 설정 / 톱니 버튼      ─→ Settings (sheet)
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

    // 네비게이션
    @State private var path: [HomeRoute] = []
    @State private var jobs: [UUID: PendingJob] = [:]
    @State private var resultsCache: [UUID: Note] = [:]

    // 시트
    @State private var showingSettings = false
    @State private var showingOnboarding = !UserDefaults.standard.hasOnboarded

    // 업로드 소스 선택
    @State private var showingUploadMenu = false
    @State private var showingPhotosPicker = false
    @State private var showingFileImporter = false

    // 카메라
    @State private var showingScanner = false

    // PhotosPicker
    @State private var photoItem: PhotosPickerItem?

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
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingOnboarding) {
                OnboardingSheet { showingOnboarding = false }
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
                selection: $photoItem,
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
            .onChange(of: photoItem) { _, newItem in
                Task { await loadPickedItem(newItem) }
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
                // 30분 이상 묵은 작업은 정리, 재개 가능한 작업 검사
                JobStateStore.shared.purgeStale()
                checkResumableJob()
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
                    onCancel: {
                        JobStateStore.shared.finish(id: jobID)
                        path.removeAll()
                    },
                    onFinish: { note in
                        JobStateStore.shared.finish(id: jobID)
                        openFreshResult(note)
                    }
                )
            } else {
                missingJobFallback
            }

        case .result(let noteID):
            if let note = resolvedNote(for: noteID) {
                ResultView(note: note) {
                    path.removeAll()
                }
            } else {
                missingJobFallback
            }

        case .recentList:
            RecentNotesView { note in
                openExistingNote(note)
            }
        }
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

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Palette.ink2)
                    .frame(width: 40, height: 40)
            }
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
                desc: "PDF·이미지 선택",
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
                systemImage: "gearshape",
                label: "설정",
                desc: "색·라벨"
            ) {
                showingSettings = true
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
    private func openFreshResult(_ note: Note) {
        resultsCache[note.id] = note
        path = [.result(noteID: note.id)]
    }

    /// 기존 노트를 결과 화면에 push. RecentNotes에서 호출되면 path에 append돼서
    /// back으로 RecentNotes 화면으로 돌아갈 수 있게.
    private func openExistingNote(_ note: Note) {
        resultsCache[note.id] = note
        path.append(.result(noteID: note.id))
    }

    // MARK: Picker handler

    private func loadPickedItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            await MainActor.run { self.activeError = .wrapped(code: "PHOTO-LOAD", message: "사진을 불러올 수 없어요.") }
            return
        }
        await MainActor.run {
            startProcessing(
                filename: "선택한 사진.png",
                totalPages: 1,
                source: .image(data)
            )
            self.photoItem = nil // 다음 선택 위해 리셋
        }
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

            // 크기 체크
            let sizeMB = fileSizeMB(at: url)
            if pages > 100 || (sizeMB ?? 0) > 50 {
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
                source: .image(data)
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
        // 다중 페이지 스캔 → 단일 PDF로 합치는 게 자연스럽지만, v0.1은 첫 이미지만 처리.
        // v0.2: 스캔 결과 N장 → 다중 페이지 Note로 직접 변환.
        guard let first = images.first,
              let data = first.jpegData(compressionQuality: 0.9) else {
            activeError = .wrapped(code: "CAM-ENCODE", message: "촬영 결과를 인코딩할 수 없어요.")
            return
        }
        let filename = "스캔 \(scanTimestamp()).jpg"
        startProcessing(
            filename: filename,
            totalPages: images.count,
            source: .image(data)
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

    private func startProcessing(filename: String, totalPages: Int, source: JobSource) {
        let id = UUID()
        let job = PendingJob(
            id: id,
            filename: filename,
            totalPages: totalPages,
            source: source
        )
        jobs[id] = job

        // 영속화: 백그라운드/콜드 재시작 대비
        let stagedURL: URL?
        let imageDataPath: String?
        let isPDF: Bool
        switch source {
        case .pdf(let url):
            stagedURL = url
            imageDataPath = nil
            isPDF = true
        case .image(let data):
            stagedURL = nil
            // 이미지 데이터를 디스크에 저장해 재개 가능하게
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("jobs", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let path = dir.appendingPathComponent("\(id.uuidString).img")
            try? data.write(to: path, options: .atomic)
            imageDataPath = path.path
            isPDF = false
        }
        JobStateStore.shared.register(JobState(
            id: id,
            filename: filename,
            totalPages: totalPages,
            stagedURL: stagedURL,
            imageDataPath: imageDataPath,
            isPDF: isPDF
        ))

        path = [.processing(jobID: id)]
    }

    // MARK: - Deeplink (Share Extension 진입)

    /// 콜드 부팅 시 진행 중이던 작업 자동 재진입.
    /// v0.1 디자인 단계는 Mock 타이머라 재진입 시 처음부터 다시 — 실제 OCR 들어가면
    /// stage/currentPage에서 이어서 시작할 수 있게 ProcessingViewModel 확장 필요.
    private func checkResumableJob() {
        guard let job = JobStateStore.shared.resumableJob else { return }
        // 데이터 소스 복원
        let source: JobSource
        if job.isPDF, let url = job.stagedURL,
           FileManager.default.fileExists(atPath: url.path) {
            source = .pdf(url)
        } else if let path = job.imageDataPath,
                  let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            source = .image(data)
        } else {
            // 파일이 사라졌으면 잡 폐기
            JobStateStore.shared.finish(id: job.id)
            return
        }

        // PendingJob 재구성 후 ProcessingView 진입
        jobs[job.id] = PendingJob(
            id: job.id,
            filename: job.filename,
            totalPages: job.totalPages,
            source: source
        )
        path = [.processing(jobID: job.id)]
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
            let (meta, dataURL) = try AppGroup.load(id: id)

            let pageCount: Int
            let source: JobSource
            if meta.utiHint == "pdf" {
                guard let doc = PDFDocument(url: dataURL), doc.pageCount > 0 else {
                    activeError = .pdfCorrupted
                    AppGroup.cleanup(id: id)
                    return
                }
                pageCount = doc.pageCount
                source = .pdf(dataURL)
            } else {
                pageCount = 1
                if let data = try? Data(contentsOf: dataURL) {
                    source = .image(data)
                } else {
                    activeError = .wrapped(code: "IMG-READ", message: "이미지를 읽을 수 없어요.")
                    AppGroup.cleanup(id: id)
                    return
                }
            }

            startProcessing(
                filename: meta.originalFilename,
                totalPages: pageCount,
                source: source
            )

            // 처리 시작 시점에는 cleanup 보류 — processing 끝난 후 cleanup.
            // (v0.2: SwiftData에 inboxID 같이 저장해서 처리 완료 시점 추적)
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
