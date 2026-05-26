# Lumark 아키텍처

> v0.1 (MVP) 기준. spec §10 폴더 구조에 맞춤.

## 레이어

```
┌──────────────────────────────────────────────────────────┐
│  Views (SwiftUI)         HomeView / ProcessingView /      │
│                          ResultView / SettingsView /      │
│                          RecentNotesView / Onboarding      │
├──────────────────────────────────────────────────────────┤
│  ViewModels              ProcessingViewModel              │
├──────────────────────────────────────────────────────────┤
│  Services (도메인 로직)   MarkdownDocument / Exporter    │
│                          PageRenderer / PDFExporter       │
│                          AppGroup / URLSchemeRouter       │
│                          PermissionService / JobStateStore│
│                          LumarkError / ExportPreferences  │
├──────────────────────────────────────────────────────────┤
│  Repositories            ColorRuleStore (UserDefaults)    │
├──────────────────────────────────────────────────────────┤
│  Models (SwiftData)      Note / Page / Highlight          │
│                          ColorCategory / ColorRule        │
└──────────────────────────────────────────────────────────┘
```

원칙:
- View는 ViewModel/Service만 호출. Model 직접 조작은 컨텍스트 통해서만.
- Service는 순수 도메인 로직 + 외부 시스템 wrapping. UI 무관.
- 도메인 값 타입(MarkdownDocument 등)은 `nonisolated + Sendable` — 백그라운드 안전.

## 데이터 모델

```
Note ── (1:N) ── Page ── (1:N) ── Highlight
  │                                  │
  ├ id: UUID                         ├ id: UUID
  ├ title                            ├ colorCategoryRaw
  ├ createdAt                        ├ text (OCR 결과)
  ├ sourceType (pdf/image)           ├ boundingBoxData
  ├ pageCount                        └ orderInPage
  ├ originalFilename
  └ isFavorite

  cascade delete + 양방향 inverse
```

`Page.imageData`는 SwiftData SQLite 본체를 부풀리지 않도록 `@Attribute(.externalStorage)`.

도메인 파생 타입 (`Services/MarkdownDocument.swift`):
```
MarkdownDocument
├ title
├ sections: [MarkdownSection]   ← 본문 (노랑·주황)
│   └ MarkdownItem (color, text, pageNumber)
├ pinkItems / blueItems          ← 추가 메모
└ colorCounts / pageToSectionMap (computed)
```

## 처리 파이프라인 (spec §5)

```
[입력] PDF / 이미지 / 카메라 스캔
   ↓
[1] PageRenderer        ← PDF → UIImage[], DPI/blank skip 처리
   ↓
[2] HighlightDetector   ← (미구현) Core Image HSV 마스킹
   ↓
[3] OCRService          ← (미구현) Vision Framework 한국어 인쇄체
   ↓
[4] 색별 그룹핑 + 정렬   ← MarkdownDocument.from(Note)
   ↓
[5] 구조 인식            ← splitByOrange (spec §6 알고리즘)
   ↓
[6] MarkdownExporter    ← .md 텍스트 (CommonMark/Obsidian)
[6] PDFExporter         ← PDF (CoreText 페이지 분할)
```

Day 2~4 게이트 통과 전까지는 [2][3]이 Mock — ProcessingViewModel이 타이머로 진행률만 흉내내고 결과는 `MockData.antibioticsNote()`.

## 라우팅 (HomeView)

```swift
enum HomeRoute: Hashable {
    case processing(jobID: UUID)
    case result(noteID: UUID)
    case recentList
}
```

상태:
- `path: [HomeRoute]` — NavigationStack 경로
- `jobs: [UUID: PendingJob]` — 메모리 잡 캐시 (Mock note 포함)
- `resultsCache: [UUID: Note]` — Note ID 룩업 캐시 (Mock + 영속 모두)

진입 흐름:
- **업로드 (PhotosPicker/fileImporter)** → `startProcessing` → `[.processing(id)]`
- **카메라** → `DocumentScannerView` → `ingestScannedImages` → `startProcessing`
- **Share Extension deeplink** (`lumark://import?id=...`) → `AppRouter.handle` → HomeView가 `ingestInbox` → `startProcessing`
- **최근 작업 row 탭** → `openExistingNote` → `path.append(.result(id))` (push)
- **변환 완료** → `openFreshResult` → `path = [.result(id)]` (replace, back은 홈)
- **콜드 재시작** → `JobStateStore.resumableJob` 검사 → 진행 중이던 잡 자동 재진입

## 영속화

```
SwiftData (~/Library/Application Support/default.store)
└ Note / Page / Highlight 그래프

UserDefaults
├ com.lumark.colorRules     ← ColorRule JSON
├ lumark.export.dialect     ← CommonMark/Obsidian
├ lumark.export.includePageMap
└ lumark.onboarded          ← 첫 실행 플래그

Application Support
└ lumark.jobs.json          ← JobStateStore (재개 가능한 작업)

Temporary
└ inbox/                    ← fileImporter staged PDF
└ jobs/                     ← 카메라/이미지 데이터 백업
└ exports/                  ← PDF 내보내기 임시 결과

App Group (group.com.lumark)
└ Inbox/                    ← Share Extension → 메인 앱 핸드오프
```

## 디자인 토큰 (Theme.swift)

OKLCh 색 공간에서 정의한 토큰을 런타임에 sRGB로 변환 (`OKLCh.toSRGB`). 가장 정확한 색 일관성 + 디자인 시안(`Lumark_design/Design System.html`)과 1:1.

```swift
Palette.brown / cream / surface / ink / brass / divider / ...
Palette.Highlight.yellow / orange / pink / blue (+ bg/edge)
```

라이트/다크 양쪽 정의는 `UIColor(dynamicProvider:)`로 시스템 자동 전환.

## 동시성

프로젝트 빌드 설정: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. 모든 타입이 기본 `@MainActor`. 백그라운드에서 돌아야 하는 것들은 명시적으로 `nonisolated`:
- `PageRenderer` (PDF 렌더)
- `PDFExporter`
- `MarkdownDocument` / `MarkdownItem` / `MarkdownSection` (값 타입)
- `LumarkError`, `LumarkDeeplink`, `JobState`

## 에러 처리 (spec §8 매트릭스)

`LumarkError` enum 14 케이스. 각각:
- `debugCode` — 디버그 로그용 (예: "OCR-EMPTY", "AG-01")
- `userTitle` / `userMessage` — 사용자 친화 문구
- `defaultActions` — 다음 행동 옵션 (절대 비어있지 않음 = 막다른 길 금지)
- `severity` — error / warning / info

`LumarkErrorView` (풀스크린) + `ErrorBanner` (인라인) + `.errorAlert(error:)` modifier 세 형태.

## Share Extension 흐름

```
[굿노트 / 사진 앱]
    ↓  공유 시트
[Share Extension UI (ShareView)]
  - 받은 PDF/이미지 썸네일
  - 색 매핑 미리보기
  - [변환 시작] 클릭
    ↓
[AppGroup.stage]
  /Inbox/{uuid}.{ext}
  /Inbox/{uuid}.json (meta)
    ↓
[deeplink] lumark://import?id={uuid}
    ↓
[LumarkApp.onOpenURL]
  → AppRouter.handle(url:)
  → pendingDeeplink 설정
    ↓
[HomeView.onChange(pendingDeeplink)]
  → ingestInbox(id:) → ProcessingView
```

## 테스트 전략

- **단위 테스트 (`LumarkTests/`)**: 도메인 로직 fixture 기반. 32개.
  - `MarkdownDocumentTests` (13) — spec §6 알고리즘 잠금. **§7 S3 게이트의 50%**.
  - `MarkdownExporterTests` (8) — spec §6 출력 포맷.
  - `PDFExporterTests` (4) — PDF invariants (열림/페이지수/sanitization).
  - `URLSchemeRouterTests` (7) — deeplink 라운드트립.

- **UI 테스트 (`LumarkUITests/`)**: 핵심 동선 회귀 방지. 3개.
  - Home → 액션 카드들 존재
  - Settings sheet 열고 닫기
  - 빈 상태 안내 표시

OCR 정확도 검증(§7 S1, S2)은 ground truth 데이터셋 준비 후 별도 평가 스크립트로.

## 다음 단계 (Day 2~4 통과 후)

1. `HighlightDetector` 서비스 구현 (Core Image HSV 마스킹)
2. `OCRService` 서비스 구현 (Vision Framework)
3. `ProcessingViewModel.runMock()` → 실제 파이프라인 호출로 교체
4. Note 그래프 빌드 → SwiftData insert
5. Day 11+ 친구 alpha 테스트
