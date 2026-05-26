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
- **실제 OCR 파이프라인** — `HighlightDetector` + `OCRService` 구현 후 ProcessingViewModel.runMock 교체
- **Share Extension Target 생성** — Xcode UI에서 capability + target + Info.plist 수동 설정
- **친구 alpha 테스트 (Day 11+)** — 본인 + 친구 1~2명 매일 사용 1주 지속 목표

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
