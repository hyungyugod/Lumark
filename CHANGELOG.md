# CHANGELOG

## [Unreleased] — v0.1 (MVP) 작업 중

### Added
- 폴더 구조 (spec §10) — App / Models / Repositories / Services / ViewModels / Views / Theme / ShareExtension
- **디자인 시스템** — `Theme.swift`. OKLCh → sRGB 런타임 변환. Light/Dark 자동 전환. 4색 형광펜 (yellow/orange/pink/blue) 토큰.
- **앱 아이콘 (방향 B)** — 펜 끝 + 4색 스트로크. Light/Dark/Tinted 3 variant. `scripts/generate-app-icon.swift`로 자동 생성.
- **워드마크** — Lumark + brass m-dot + k-flourish. SwiftUI ZStack 합성.
- **모델** — `Note` / `Page` / `Highlight` (SwiftData @Model). `ColorCategory` / `ColorRule` / `HSVRange`. `Note.isFavorite` 추가.
- **MockData** — "항생제정리" 4페이지 시안 데이터, Preview/디자인 단계용.
- **화면** — HomeView / ProcessingView / ResultView / SettingsView / RecentNotesView / OnboardingSheet.
- **컴포넌트** — ActionCard, ActionCardContent, HintBanner, EmptyStateView (디자인 시안 SVG 라인 아트를 SwiftUI Path로), RecentNoteRow, LumarkWordmark, AppIconView, ColorFilterChip, MarkdownBodyView, PDFFauxView, ResultActionBar, NoteRenameSheet, DocumentScannerView, ErrorView (LumarkErrorView + ErrorBanner + .errorAlert modifier).
- **도메인 서비스**
  - `MarkdownDocument` — spec §6 알고리즘 (주황으로 섹션 분할 + 분홍/파랑 분리). `colorCounts` / `pageToSectionMap` 파생.
  - `MarkdownExporter` — CommonMark / Obsidian dialect. 페이지 매핑 표 옵션. 색별 통계 footer.
  - `PageRenderer` — PDF → UIImage[] (PDFKit, DPI 조절, 빈 페이지 자동 스킵).
  - `PDFExporter` — MarkdownDocument → PDF (CoreText 페이지 자동 분할).
  - `LumarkError` — spec §8 13가지 케이스 매트릭스 + actions + severity.
  - `PermissionService` — 카메라/사진 권한 + 시스템 설정 열기.
  - `AppGroup` — Share Extension ↔ 메인 앱 inbox stage/load/cleanup.
  - `URLSchemeRouter` — `lumark://import?id=...` 파싱/빌드.
  - `JobStateStore` — 처리 중 작업 디스크 영속화 + BackgroundTaskExtender.
  - `ExportPreferences` — 사용자 마크다운 출력 옵션 (UserDefaults).
- **App 진입점**
  - `LumarkApp` — ModelContainer + AppRouter + onOpenURL deeplink handler.
  - `AppRouter` — pendingDeeplink consume 패턴 (@Observable).
  - `AppRouting` — HomeRoute / JobSource / PendingJob.
- **Share Extension 코드** — ShareViewController + ShareView (UIHostingController + responder chain으로 메인 앱 호출). Target 생성은 Xcode UI에서 수동 (가이드: `docs/share-extension-setup.md`).
- **노트 라이브러리** — 검색 / 정렬 (최근/오래된/이름/페이지) / 즐겨찾기. 즐겨찾기 상단 고정. context menu + swipe action.
- **결과 화면 폴리쉬** — 마크다운 텍스트 selectable, 페이지 번호 표시, 색별 통계, Obsidian dialect 토글.
- **백그라운드 상태 보존 (spec §8)** — ProcessingViewModel이 진행 상태를 JobStateStore에 저장. BackgroundTaskExtender로 BG 시간 연장. 콜드 부팅 시 30분 이내 작업은 자동 재개.
- **카메라 입력** — VNDocumentCameraViewController UIViewControllerRepresentable.
- **온보딩** — 첫 실행 시 3페이지 TabView 안내 (형광펜 → 굿노트 공유 → 라이브러리). 설정에서 다시 보기 가능.
- **다크 모드** — 모든 토큰 자동 전환. 시뮬레이터 검증 완료.
- **VoiceOver** — ActionCard / ColorFilterChip / RecentNoteRow에 접근성 라벨.
- **Info.plist 키** — `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription`.

### Testing
- **단위 테스트 32개 (LumarkTests/)**
  - MarkdownDocumentTests (13) — spec §6 알고리즘 fixture 잠금
  - MarkdownExporterTests (8) — spec §6 출력 포맷
  - PDFExporterTests (4) — PDF invariants
  - URLSchemeRouterTests (7) — deeplink 라운드트립
- **UI 테스트 3개 (LumarkUITests/)**
  - 홈 화면 액션 카드 존재
  - Settings sheet 열고 닫기
  - 빈 상태 안내 표시

### Documentation
- `README.md` — 프로젝트 개요, 빌드, 디렉토리
- `docs/architecture.md` — 레이어, 데이터 모델, 파이프라인, 라우팅, 영속화, 동시성, 에러, Share Extension, 테스트
- `docs/share-extension-setup.md` — Xcode 수동 단계 가이드
- `Lumark-v0.1-spec.md` — 원본 사양서

### Deferred to next
- **Day 2~4 합격 게이트** (spec §7) — ground truth 3장 준비 후
  - S1: HSV 마스킹 정밀도 ≥ 95% / 재현율 ≥ 90%
  - S2: OCR CER ≤ 5% / WER ≤ 10%
  - S3: 섹션 분할 일치 ≥ 90% (알고리즘 부분은 이미 단위 테스트로 잠금)
- **Share Extension Target 생성** — Xcode UI에서 capability + target + Info.plist 수동 설정
- **친구 alpha 테스트 (Day 11+)** — 본인 + 친구 1~2명 매일 사용 1주 지속 목표

### Added (실제 OCR 파이프라인 — 2026-05-27)
- **`HighlightDetector`** — Core Image 의존 없이 픽셀 직접 처리. 작업 해상도(긴 변 1200px) 다운샘플 → RGBA8 → HSV 마스크 → 4-이웃 BFS 연결요소 → minArea 노이즈 컷 → 원본 좌표 역매핑. 정렬은 줄(line) 키 양자화 후 y → x. 활성 색·`isEnabled` 둘 다 만족하는 룰만 사용.
- **`OCRService`** — Vision `VNRecognizeTextRequest` `.accurate` + `recognitionLanguages = ["ko-KR", "en-US"]`. 영역별로 CGImage cropping 후 OCR. observation 정렬은 normalized Vision 좌표(좌하단 원점) 기준 위→아래, 왼→오른쪽. 영역 OCR 실패 = 빈 문자열.
- **`ProcessingViewModel.runReal`** — `runMock`을 디자인 fallback으로 보존하고, `source != nil`일 때 실제 파이프라인 실행. 단계별 진행률(splittingPages 10% / detect 20% / OCR 55% / assemble 15%) + 페이지별 currentPage 갱신.
- **에러 surface** — `ProcessingViewModel.error: LumarkError?` 추가, `ProcessingView`에 `.errorAlert(error:)` 연결. spec §8 케이스 매핑: PDF 손상 → `.pdfCorrupted`, 검출 0개 → `.noHighlightsDetected`, OCR 전부 빈 문자열 → `.ocrAllEmpty`, 그 외 → `.wrapped`.
- **`Note` 그래프 조립** — PageRenderer가 만든 UIImage를 JPEG로 직렬화해 `Page.imageData`(외부 스토리지)에 저장. OCR 빈 문자열은 `Highlight` 생성에서 스킵해 spec §8 "부분 성공 허용".

### Testing (2026-05-27)
- **HighlightDetectorTests (7)** — 합성 UIImage로 contract 잠금. 단일 노랑 블롭, 노랑+주황 혼합, 빈 페이지, 비활성 색 무시, minArea 필터링, 위→아래 정렬, 빈 rules.
- **OCRServiceTests (3)** — Vision 호출 contract smoke. 빈 regions, regions 길이 일치, 합성 영문 텍스트 → 비어있지 않은 결과.
- 총 단위 테스트 31 → 41개.

### Added (E2E 검증 + 디버그 오버레이 — 2026-05-27)
- **`PipelineIntegrationTests` (2)** — HighlightDetector → OCRService → MarkdownDocument 한 바퀴. 합성 페이지(흰 배경 + 형광 사각형 + 검정 텍스트)로 색 카운트·섹션 구조·OCR 텍스트 토큰을 동시에 검증. ProcessingViewModel.assembleNote와 일치하는 SwiftData 그래프 조립 패턴을 외부에서 mirror — 둘이 어긋나면 이 테스트가 잡는다.
- **Morphological closing (HighlightDetector)** — 형광펜 위 검정 텍스트 글리프는 HSV 범위 밖이라 마스크에 구멍을 만들어 한 highlight를 여러 blob으로 쪼갠다. dilate K번 → erode K번으로 ~2K픽셀 폭 stroke를 메움. **Separable sliding window**로 구현해 1200x1600 페이지에서 ~1.5s/페이지 (naïve 8-이웃 반복 ~18s/페이지의 12배 빠름).
- **`DebugPreferences`** — UserDefaults 영속 토글. v0.1은 `showDetectionOverlay` 하나. Day 2~4 합격 게이트 HSV 튜닝 작업의 단일 진입점.
- **`DetectionOverlayView`** — Note의 페이지 imageData를 디코드해 표시 + (옵션) Highlight bbox를 색별 외곽선 + 18% 채움으로 덧그림. ResultView "원본" 탭이 실 페이지가 있으면 이걸 쓰고, mock 노트는 PDFFauxView 폴백.
- **SettingsView 디버그 섹션** — "검출 영역 표시" 토글 + 안내 문구.
- **`Note.pages` / `Page.highlights` 배열 할당으로 통일** — ModelContext 밖에선 `append`가 불안정해 통합 테스트가 0개 섹션을 보던 문제. ProcessingViewModel.assembleNote도 동일 패턴으로 정리.
- 총 단위 테스트 41 → 43개.

### Changed (v0.1 색 범위 축소 — 2026-05-26)
- **v0.1 활성 색을 노랑/주황으로 한정.** 실제 간호학 PDF 페이지(여성건강간호학 §대아심박동) 검토 결과 분홍/파랑은 본문 섹션에서 분리하기보다 본문에 inline으로 자연스럽고, 분홍/파랑 highlight 자체가 페이지에 없는 경우가 더 흔함. 분홍/파랑 검출·렌더는 v0.2+ 백로그로 이동.
- 단일 진리원으로 `ColorCategory.activeInV01: [.yellow, .orange]` 도입 — UI/defaults/exporters 모두 이걸 사용. v0.2에서 케이스 추가만으로 재활성.
- 보존: `ColorCategory` enum의 `.pink`/`.blue` 케이스, Theme 토큰(Highlight.pink/blue/pinkBG/blueBG/pinkEdge/blueEdge), 앱 아이콘 4색 스트로크 — 브랜드 자산 + SwiftData 호환성 유지.
- 제거: `MarkdownDocument.pinkItems`/`blueItems`/`hasSupplementary`, MarkdownExporter "### 추가 메모" 섹션, PDFExporter 동일 블록, MarkdownBodyView supplementary 섹션, SettingsView "분홍·파랑 = 추가 메모" 안내 카드, ResultView 분홍/파랑 chip, MockData 분홍/파랑 fixture, `ColorRuleSnapshot`/`currentSnapshot` (사용처 소멸).
- 테스트 32 → 27개 (분홍/파랑 잠금 5개 제거 + `inactiveColorsIgnored`/`onlyInactiveColors` 2개 추가).

### Changed (정합성·확장성 정리 — 2026-05-26)
- **ColorRule이 출력 파이프라인까지 도달.** `ColorRuleSnapshot` (값 타입, Sendable) 도입 → MarkdownExporter / PDFExporter / MarkdownBodyView 라벨 통합. ResultView chips 초기값은 `ColorRule.isEnabled` 기반, chip 라벨은 사용자 라벨 우선.
- **`Note.sourceType: String` → `NoteSource` enum.** SwiftData 컬럼은 호환 유지(`sourceType: String`), 사용처는 `note.source` 게터 사용.
- **AppGroup inbox cleanup 호출 누락 수정.** `PendingJob` / `JobState`에 `inboxID: UUID?` 영속화. `HomeView.finalizeJob`이 종료 시점에 단일 호출.
- **"처음 안내 다시 보기" 작동.** SettingsView dismiss 감지 → `UserDefaults.hasOnboarded` 재평가 → onboarding 시트 재표시.
- **`JobStateStore.finish` 책임 단일화.** ProcessingViewModel 내부 호출 제거 → view layer `finalizeJob`이 단일 호출 지점.
- **`ProcessingViewModel.init`에 `source`/`resumeFrom` 인터페이스 추가.** Mock 단계에선 미사용, Day 5+ 실제 파이프라인 연결 시 갈아끼우는 지점만 미리 마련.
- **`RecentNotesView`의 `try? modelContext.save()` silent fail 제거.** ResultView와 동일하게 `errorAlert` 패턴 적용 — spec §8 "데이터 절대 안 잃음".
- **`JobSource: Sendable`, `ColorCategory: Sendable` 명시.**

### Notes
- 프로젝트 빌드 설정 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. 백그라운드 안전 코드는 명시적 `nonisolated`.
- Xcode iOS Simulator 26.5, iPhone 17 기준 빌드/테스트.
- 디자인 시안 출처: `Lumark_design/` (Claude Design 산출물).
