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

### Changed (Gemini 프롬프트 줄 정리 — 2026-05-28)
- **프롬프트에 줄 정리 지시 추가.** 여러 줄에 걸친 한 형광펜 강조를 하나의 항목으로 합치고, 줄바꿈으로 쪼개진 단어("바"+"탕"→"바탕")·문장을 완성된 문장으로 이어붙임. 2단 컬럼 읽기 순서(왼쪽 단 먼저)도 명시. 내용 지어내기/의미 변경은 여전히 금지. 같은 API 호출 안에서 처리 — 추가 비용 0.
- **제목 처리 지시 추가.** 여러 어절·여러 줄 제목을 쪼개지 않고 한 항목으로, 페이지마다 반복되는 제목은 동일 텍스트로 반환 → 앱의 dedup이 작동해 "비신생물적 증식"이 한 번만 ## 으로.

### Changed (전체 페이지 OCR + 토큰 비용 최적화 — 2026-05-28)
- **OCR을 "페이지 통째 → Gemini" 방식으로 전환.** region마다 crop해서 N번 호출하던 방식 폐기 — underline에서 fragmentation + 인접 줄 누출 + 호출 수 폭증. 이제 페이지 1장 = API 1회, Gemini가 형광펜 영역을 직접 찾아 텍스트+색을 읽기 순서로 반환.
- **`OCRProvider` 프로토콜을 `recognizePage(image:regions:) -> [OCRSpan]`로 변경.** `OCRSpan = {text, color, boundingBox?}`. Vision은 region 색+bbox 보존(디버그 오버레이 유지), Gemini는 색을 직접 분류하고 bbox는 nil.
- **토큰 비용 최적화** (무료 배포 + 개발자 자비 부담 대응):
  - 페이지당 1 call (region당 N call → 페이지당 1)
  - **빈 페이지 스킵** — HSV 색 0개 페이지는 API 호출 안 함
  - **다운샘플** — 220 DPI 원본을 긴 변 1536px로 축소해 입력 토큰 절감
  - **기본 모델 Flash Lite** ($0.10/$0.40)
  - `maxOutputTokens: 2048` + `temperature: 0`
  - 추정: 20페이지 노트 ≈ 10원, 친구 5명 일상 사용 시 월 3~5천원
- **20페이지 변환 상한.** PhotosPicker maxSelectionCount 20, PDF/Share inbox 20p 초과 차단, 카메라 스캔 20장 캡. 외부 OCR 토큰 비용 상한 보장.
- 색 분류를 Gemini가 직접 → HSV 색역 튜닝 부담 감소 (HSV는 빈 페이지 게이트 + 디버그 오버레이용으로만).
- GeminiOCRProviderTests를 spans 스키마 + 다운샘플 검증으로 재작성.

### Fixed (underline 가로 병합 재설계 — 2026-05-28)
- **가로 병합 "같은 줄" 판정을 이미지 높이 기반 안정 band로.** 기존엔 `yDiff ≤ minH × 0.6`이라 underline(높이 ~4px)은 임계값이 2.4px밖에 안 돼서, 줄 안 흔들림 때문에 같은 줄인데도 "다른 줄"로 판정 → 단어마다 쪼개짐. 이제 `lineBand = max(8, imageHeight × 1.1%)`로 줄 간격보단 작고 흔들림보단 큰 안정 값 사용.
- **midY 정렬 후 greedy 줄 클러스터링** — 고정 bin 경계 straddle 문제 회피. 줄 안에서 x 정렬 후 gap(≤ 6% 폭) 병합.
- 실 페이지에서 "분화된 조직의 한 형태에서 다른 것으로 변화된 것"이 7~8조각 → 1개 영역으로 병합. 테스트 2개 추가 (흔들리는 y / 줄 간격 분리).

### Added (Lumark Cloud 프록시 — 2026-05-28)
- **`server/ocr-proxy` Cloudflare Worker.** Gemini 키를 서버 secret에 보관, 앱은 키를 모름(추출 불가). 다운샘플 이미지를 받아 Gemini 호출 후 spans 반환. **기기당 + 전체 일일 페이지 한도**(KV 카운터)로 청구서 상한. 배포 가이드 `server/ocr-proxy/README.md`.
- **AI Gateway 경유 (지역 차단 회피).** Cloudflare Worker 직접 egress가 Gemini 미지원 리전으로 잡혀 "User location is not supported" 발생 → AI Gateway(`gateway.ai.cloudflare.com/.../google-ai-studio/`) 경유 + `x-goog-api-key` 헤더로 우회. CF_ACCOUNT_ID/CF_GATEWAY env로 토글, 미설정 시 직접 호출 폴백. 실 이미지 E2E 검증 완료(한국어 OCR 정상).
- **`OCREngine.lumarkCloud`** 신규 + 기본값. 키 입력 없이 프록시 경유. `ProxyOCRProvider`가 다운샘플→base64→Worker POST(X-Device-ID)→spans. 429(한도초과)는 친화적 메시지 + "내 Gemini 키로 전환" 안내.
- **기기 익명 UUID** (UserDefaults) — 프록시 기기당 한도 카운팅용.
- 엔진 3종: Lumark Cloud(기본·키 불필요) / 내 Gemini 키(고급·무한도) / Apple Vision(오프라인).
- ⚠️ 배포 전까지 `lumarkCloudEndpoint`가 placeholder라 lumarkCloud는 안내 에러. 그동안 "내 Gemini 키" 사용. (기존 사용자는 선택이 UserDefaults에 남아 그대로 동작.)
- ProxyOCRProviderTests 6개 추가.

### Changed (Gemini 기본 모델 2.5로 — 2026-05-28)
- **기본 모델 gemini-2.0-flash → gemini-2.5-flash.** 2.0-flash가 2025년 이후 신규 계정에 404("no longer available to new users"). 신규 계정에서 동작하는 2.5 계열을 기본값으로. 저장된 모델이 2.0-flash면 로드 시 2.5-flash로 자동 승격. picker에서 2.0/1.5는 "기존 계정 전용"으로 표기.

### Added (Gemini quota 대응 — 2026-05-28)
- **모델 선택 picker.** `GeminiModel` enum (2.0-flash / 2.5-flash-lite / 2.5-flash / 1.5-flash). 2025-12 Google 무료 티어 quota 축소로 2.0-flash가 429 나는 경우, Settings에서 더 관대한 모델로 전환 가능. OCRPreferences에 영속화.
- **429/503 지수 백오프 재시도.** GeminiOCRProvider가 quota/overload 응답을 1s→2s→4s로 최대 3회 재시도. ghost 429 + 분당 rate limit 대응. 끝까지 실패하면 billing 안내 포함 에러 메시지.

### Added (Gemini 2.0 Flash OCR provider — 2026-05-28)
- **`OCRProvider` 추상화.** 기존 `OCRService`는 그대로 두고 `VisionOCRProvider`가 wrap. 새 provider는 protocol에 맞추기만 하면 끼움.
- **`GeminiOCRProvider`** — Google AI Studio `gemini-2.0-flash:generateContent`. 페이지 단위 batch (한 페이지의 모든 region을 한 API call에). 각 region을 client 측에서 crop → JPEG → base64 → multi-image content. `responseMimeType: application/json` + `responseSchema` 강제로 안전 파싱. 12페이지 노트 변환 약 4원 (Haiku의 10분의 1).
- **`OCRPreferences`** — engine 선택(UserDefaults) + API 키 보관(Keychain). `selectedProvider()` 팩토리로 ProcessingViewModel이 매번 새 인스턴스 받음.
- **`SecureStore`** — Keychain 얇은 wrapper (`kSecClassGenericPassword`, `kSecAttrAccessibleAfterFirstUnlock`).
- **SettingsView "OCR 엔진" 섹션** — Picker(Apple Vision / Gemini) + 엔진 설명 + Gemini 선택 시 SecureField로 API 키 입력 + AI Studio 발급 링크. 키 등록/삭제 UI.
- **ProcessingViewModel** — OCR 단계에서 `OCRPreferences.shared.selectedProvider()` 호출. provider 에러는 `LumarkError.wrapped(code: "OCR-PROVIDER", ...)`로 surface.
- **테스트 9개 추가** — `GeminiOCRProviderTests`: 요청 본문 형태 / crop 스킵 / 정상 응답 / 길이 mismatch / 잘못된 JSON / 누락 키. 실제 네트워크 호출은 없음.

### Fixed (underline padding 누출 — 2026-05-28)
- **adaptive vertical padding을 비대칭으로 변경.** underline 형 blob(얇은 가로 띠)에서 위/아래 모두 4배 padding을 적용하던 게 다음 줄 텍스트까지 OCR bbox에 빨려 들어가는 누출을 만듦 (예: "1 2) 병리적 과형성 Hyperplasi 피부의 만성적인 자극 (염 (1)"처럼 두 줄이 한 OCR 결과로 섞임). 위쪽 padding만 4배 유지(텍스트 본체는 underline 위에 있음), 아래쪽 padding은 일반 값 유지.
- HighlightDetectorTests에 `underlinePaddingIsAsymmetric` 추가 — top extension ≥ 25 AND bottom ≤ 15 AND top > 2×bottom 잠금.

### Changed (HSV 경계 이동 — 2026-05-27)
- **orange / yellow hue 경계 40° → 50°.** Goodnotes "orange" 형광펜이 hue 40~50° 영역에 있어 우리 yellow 범위로 흘러 들어가던 문제. orange 범위 15~40° → 15~50°, yellow 범위 40~70° → 50~70°. 합성 테스트 색(hue 30° / 54°)은 경계 변경에 영향 없음. **기존 사용자는 Settings → "기본값으로 되돌리기" 한 번 필요** (UserDefaults 캐시된 OLD HSV 갱신).
- **orange sMin 0.35 → 0.30.** opacity 낮춰 칠한 옅은 highlight 도 잡히게.

### Added (실 페이지 정성 검증 패치 — 2026-05-27)
- **OCR ko-KR only.** `OCRService.recognitionLanguages = ["ko-KR"]`. en-US를 함께 두면 Vision이 한국어 조사 "이"를 라틴 "O"로 추론하는 사례(예: "FHR이" → "FHRO")가 잡힘. ko-KR 모델은 한국어 문서에 흔히 섞인 영문 단어(hypertrophy 등)도 충분히 잘 읽음.
- **줄 wrap 병합 (HighlightDetector).** 한 형광펜 stroke가 페이지 텍스트 줄을 넘어 2~3줄로 이어진 경우, 줄 사이 공백 때문에 별개 blob으로 분리되어 N개의 Highlight = N개의 bullet로 쪼개지던 문제. 같은 색 + 세로 인접(yGap ≤ min(h)*1.2) + 가로 연속(겹침 OR wrap 패턴: prev 우측존 + next 좌측존) 시 union으로 병합. `HighlightDetectorOptions.mergeWrappedLines` 로 토글 가능 (기본 ON).
- **`minRegionRatio` 0.00015 → 0.00010.** 얇은 underline 형태 highlight도 잡히도록 방어적 튜닝.
- **페이지 헤더 dedup (MarkdownDocument).** 슬라이드 노트처럼 매 페이지 상단에 같은 주황 제목이 반복되는 패턴에서, 같은 텍스트의 두 번째 이후 주황은 무시 → 한 노트에 같은 `##`가 N번 찍히지 않음. 직후 노랑은 직전 섹션에 이어 붙음.
- **사진 다중 선택.** PhotosPicker `maxSelectionCount: 100`, `selectionBehavior: .ordered`. 선택 순서가 페이지 순서가 됨. 카메라 스캔도 모든 페이지를 다중 페이지 Note로 ingest (기존: 첫 장만).
- **`JobSource.image(Data)` → `JobSource.images([Data])`.** 단일 이미지는 `[data]` 한 원소 배열. 모든 ingest 경로(PhotosPicker / FileImporter / Camera / Share Extension inbox)가 통일된 시그니처로 진입.
- **`JobState.imageDataPath: String?` → `imageDataPaths: [String]?`.** Codable 마이그레이션 (legacy 단수 키 자동 fallback). 잡 영속화 디렉토리는 `jobs/<id>/p0000.img` 패턴.
- **`HighlightDetectorOptions.mergeWrappedLines: Bool`** 옵션 신규.
- 단위 테스트 43 → 50개 (HighlightDetector merge 4 + MarkdownDocument dedup 2 + PageRenderer 변경에 따른 OCR/Pipeline 영향 없음).

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
