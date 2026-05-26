# Lumark v0.1 사양서

> **작성일**: 2026-05-21
> **버전**: v0.1 (MVP)
> **타겟 사용자**: 간호학과 학생 (본인 + 친구들)
> **한 줄 요약**: 형광펜만 그으면, 정리 노트가 알아서 쌓이는 iOS 앱

---

## 0. 핵심 가치 (변하지 않을 북극성)

- **마찰 0**: 공부 흐름을 한 번도 끊지 않음
- **색깔 = 의미**: 색상별 자동 분류 (노랑 = 핵심, 주황 = 주제)
- **누적의 힘**: 한 학기치 공부가 자동으로 정리본이 되어 시험 직전 복습에 활용

---

## 1. v0.1 범위

### 포함

- 굿노트 PDF 공유 시트 수신 (Share Extension)
- 사진 앱 공유 시트 수신 (이미지)
- 메인 앱 홈에서 PDF/이미지 picker
- 메인 앱 홈에서 카메라 입력 (`VNDocumentCameraViewController`)
- 형광펜 다중 색 검출 (노랑/주황 기본, 분홍/파랑 옵션)
- 색별 자동 분류 + 구조 인식 (주황 = 섹션 제목, 노랑 = 글머리표)
- 인쇄체 한국어 OCR (Apple Vision Framework)
- 마크다운 출력 (CommonMark) + PDF 내보내기
- SwiftData 기반 노트 라이브러리 (홈에서 최근 작업)
- 결과 화면: 마크다운 미리보기 ↔ 원본 PDF 탭 토글, 색상 토글, 복사/공유/PDF 내보내기
- 색 매핑 사용자 라벨 입력
- 변환 진행률·취소
- 부분 성공 허용 + 안전한 실패 UX

### v0.2+ 백로그

- **ReplayKit 기반 실시간 캡처 모드** (백그라운드 녹화 → 페이지 프레임 자동 추출 → 후처리). Lumark의 진짜 vision.
- 빨간펜 손글씨 "단어:설명" 패턴 인식 (외부 OCR API 검토)
- HSV 미세조정 UI (사용자 캘리브레이션)
- iCloud 동기화
- 노트 검색·태그·전문검색 (SQLite FTS)
- Notion·Obsidian 직접 연동
- Obsidian markdown dialect 옵션 (`==형광펜==` 변환)
- 퀴즈 카드 변환 (OpenClaw 봇 연동 가능성)

---

## 2. 화면 구성

```
[HomeView]
 ├─ [업로드 / 변환 시작]   ──→ [ProcessingView] ──→ [ResultView]
 ├─ [카메라]               ↑                          ├─ 마크다운 ↔ 원본 PDF 탭
 ├─ [최근 작업]            │                          ├─ 색상 토글 (노랑/주황/분홍/파랑)
 ├─ [설정]                 │                          └─ [복사] [공유] [PDF 내보내기]
 └─ 안내 "굿노트에서 공유로" │
                           │
[굿노트 공유 시트] → [ShareView] ┘
[사진 앱 공유 시트] → [ShareView] ┘

[SettingsView] ← 색 매핑 / 구조 룰 안내 / 정보
```

### 화면별 명세

**HomeView**
- 헤더: Lumark
- 주요 액션: [업로드] [카메라] [최근 작업] [설정]
- 안내: "굿노트에서 공유로 보내면 자동으로 받아요"

**ShareView (Share Extension UI)**
- 받은 PDF/이미지 썸네일 1~3장
- 현재 색 매핑 미리보기 ("노랑=핵심 / 주황=주제")
- [변환 시작] 버튼

**ProcessingView**
- 페이지별 진행률 ("3/12 페이지 OCR 중")
- [취소] 버튼

**ResultView**
- 탭 토글: 마크다운 ↔ 원본 PDF 미리보기
- 색상 필터 토글: 노랑/주황/분홍/파랑 각각 켜고 끄기
- 하단 액션: [복사] [공유] [PDF 내보내기]

**SettingsView**
- 색상 매핑 (4색 × 활성·라벨)
- 구조 인식 룰 안내 (정보 표시만, 수정 불가)
- 앱 정보 / 버전

---

## 3. 데이터 모델 (SwiftData)

```
┌─ Note ──────────────────── (변환 1회 = 1개)
│  id: UUID
│  title: String
│  createdAt: Date
│  sourceType: String (pdf / image)
│  pageCount: Int
│  originalFilename: String?
│
│  └── Page ──────────────── [1:N]
│       id: UUID
│       pageNumber: Int
│       imageData: Data       (@Attribute(.externalStorage))
│
│       └── Highlight ────── [1:N]
│            id: UUID
│            colorCategory: ColorCategory (enum)
│            text: String       (OCR 결과)
│            boundingBoxData: Data
│            orderInPage: Int   (위→아래 순서)
│
└─────────────────────────────

@Relationship(deleteRule: .cascade) 양방향 + 자식 자동 삭제
```

### enum 정의

```swift
enum ColorCategory: String, Codable {
    case yellow, orange, pink, blue
}
```

### 앱 전역 설정 (UserDefaults, key: `"com.lumark.colorRules"`)

```swift
struct ColorRule: Codable, Identifiable {
    let id: UUID
    let color: ColorCategory
    var label: String        // 사용자 입력
    var isEnabled: Bool
    let hsvRange: HSVRange   // 코드 내장 (v0.1 미세조정 UI 없음)
}

struct HSVRange: Codable {
    let hMin, hMax: Double
    let sMin: Double
    let vMin: Double
}
```

### 초기값

| 색 | 기본 라벨 | 기본 활성 | 출력 역할 |
|---|---|---|---|
| 🟡 노랑 | 핵심 | ✅ ON | 글머리표 (`- 본문`) |
| 🟠 주황 | 주제 | ✅ ON | 섹션 제목 (`## 제목`) |
| 🩷 분홍 | (빈값) | ⬜ OFF | "추가 메모" 섹션 |
| 🔵 파랑 | (빈값) | ⬜ OFF | "추가 메모" 섹션 |

### 설계 원칙

- **Section은 엔티티 X**, 출력 시 highlight 순서대로 파생 계산
- `Page.imageData`는 SwiftData SQLite 본체를 부풀리지 않도록 외부 파일 저장
- ColorRule은 사용자 단위 전역 1세트이므로 UserDefaults (SwiftData 과잉)

---

## 4. Share Extension 설계

### App Group 설정

- Group ID: `group.com.lumark`
- 메인 앱 + Extension 양쪽 Capabilities에 등록

### 수신 가능 타입

- `com.adobe.pdf` (PDF)
- `public.image` (이미지)

### 데이터 흐름

```
[굿노트 / 사진 앱]
    ↓  공유 시트
[Share Extension]
  - 받은 파일 미리보기
  - 색매핑 표시
  - [변환 시작] 클릭
    ↓
[App Group 폴더]
  /Inbox/{uuid}.pdf
  /Inbox/{uuid}.json (메타: 원본 파일명, 받은 시각)
    ↓  URL Scheme deeplink
[Lumark 메인 앱]
  lumark://import?id={uuid}
    ↓
  onOpenURL 핸들러 → Inbox 로드 → ProcessingView
    ↓
  OCR + 변환 (메인 앱에서 실행)
    ↓
  SwiftData 저장 → ResultView
```

### 원칙

- **변환(OCR)은 절대 Extension 안에서 하지 않음** (메모리·시간 제약)
- Extension은 데이터 받아서 App Group에 저장하고 deeplink만 호출 → 빨리 종료
- 메인 앱이 정상 lifecycle에서 작업 수행

### 권한 (Info.plist)

```xml
<key>NSCameraUsageDescription</key>
<string>종이 자료의 형광펜 표시를 인식하기 위해 카메라를 사용합니다.</string>
```

---

## 5. 처리 파이프라인

```
[입력] PDF / 이미지 / 카메라 스캔
    ↓
[1] 페이지 분리 (PDFKit, PDF 일 때)
    ↓
[2] 형광펜 영역 검출 (Core Image, HSV 마스킹)
    ↓
[3] 마스킹된 영역만 OCR (Vision Framework, 한국어 인쇄체)
    ↓
[4] 색상별 그룹핑 + 페이지·위치 순서 보존
    ↓
[5] 구조 인식 (주황 사이 = 섹션, 먼저 등장한 주황 = 제목)
    ↓
[6] 마크다운 조립
    ↓
[출력] .md (복사·공유) / .pdf (PDFKit 렌더링)
```

### 단일 진입점 원칙

4가지 입력 경로 (굿노트 공유 / 사진 공유 / picker / 카메라) 모두 결국 **PDF 또는 이미지 배열**로 통일되어 같은 파이프라인을 탐.

---

## 6. 마크다운 출력 포맷

### dialect: CommonMark (Notion·GitHub·Obsidian 호환)

### 예시

```markdown
# 항생제정리

## (주제 미지정)

- 첫 페이지에 주황 없이 노랑만 있던 항목들

## 항생제의 분류

- 베타락탐계는 세포벽 합성을 억제
- 페니실린 알레르기 환자 주의
- 세팔로스포린은 1~5세대까지

## 부작용 모니터링

- 신독성 신호 — BUN/Cr 상승
- 청신경 독성 — 가역적
- 위막성 대장염 — 클로스트리디움 디피실

---

### 추가 메모

**보충 (분홍)**

- 분홍 펜으로 표시된 항목들

**주의 (파랑)**

- 파랑 펜으로 표시된 항목들

---

| 페이지 | 매핑된 섹션 |
|---|---|
| p.1 | 주제 미지정 (항목 2) |
| p.2 | 항생제의 분류 (항목 3) |
| p.3 | 부작용 모니터링 (항목 2) |
| p.4 | 부작용 모니터링 (항목 1) |

---

> 변환 정보: 항생제정리.pdf · 4페이지 · 2026-05-21 변환
```

### 출력 알고리즘 (의사 코드)

```swift
func generateMarkdown(note: Note) -> String {
    // 1. 모든 Highlight를 (페이지, 페이지 내 순서)로 정렬
    let highlights = note.pages
        .sorted { $0.pageNumber < $1.pageNumber }
        .flatMap { page in
            page.highlights.sorted { $0.orderInPage < $1.orderInPage }
        }

    // 2. 주황 등장 인덱스로 섹션 분할
    let sections = splitByOrangeMarkers(highlights)
    // sections[0] = 첫 주황 이전 노랑들 → "주제 미지정"
    // sections[1..] = 각 주황을 제목으로 가짐

    // 3. 분홍/파랑은 별도 풀로 분리 ("추가 메모")
    let (primary, supplementary) = separateAuxColors(sections)

    // 4. 페이지 매핑 표 생성
    let pageMap = buildPageMap(note)

    // 5. 조립
    return assemble(
        title: note.title,
        sections: primary,
        supplementary: supplementary,
        pageMap: pageMap,
        note: note
    )
}
```

---

## 7. 기술 검증 합격 기준 (Day 2~4 게이트)

**원칙**: 3 stage 모두 GREEN이어야 MVP 통합(Day 5) 진입.

| 단계 | 측정 항목 | 합격선 | 실패 시 대응 분기 |
|---|---|---|---|
| **S1. HSV 마스킹** | 정밀도 / 재현율 | 정밀도 ≥ 95%, 재현율 ≥ 90% | HSV 범위 재조정 → 못 잡으면 사용자 캘리브레이션 UI를 v0.1에 재도입 |
| **S2. OCR (인쇄체 한국어)** | CER / WER | CER ≤ 5%, WER ≤ 10% | Vision Framework 한계 → Naver Clova OCR 유료 검토 (철학 trade-off 의식적으로) |
| **S3. End-to-End 구조** | 섹션 분할 일치 + 정성 | 섹션 일치 ≥ 90% + "친구에게 보낼 만함" 통과 | 룰 단순화 (색별 평면 나열만, 섹션 룰 v0.2로 미룸) |

### 테스트 데이터셋

- PDF 5~10장 (간호학과 자료, 인쇄체 본문)
- 노랑·주황 다수, 분홍·파랑 일부
- **샘플 3장**: 정확한 ground truth → 정량 측정
- **나머지 5~7장**: 정성 평가 체크리스트

### 검증 단계 외부 검증자 코멘트

이 합격선을 **숫자로 박아두는 것** 이 본인 약점(다재다능형의 "안 되는데 그냥 다음 단계로 넘어감" 함정)에 대한 가장 강력한 보완책. 게이트 RED면 Day 5 진입을 멈추고 S1/S2/S3 분기 따라가는 것 — 시스템 사고 강점의 실제 작동 지점.

---

## 8. 위험·예외 케이스 대응

### 13가지 케이스 매트릭스

| 단계 | 케이스 | 대응 |
|---|---|---|
| **입력** | 형광펜 영역 0개 | "감지되지 않았어요" + [재시도] [설정 열기] |
| | PDF 손상 | "파일을 열 수 없어요" + [다른 파일 시도] |
| | 입력 너무 큼 (>50MB or >100p) | 경고 + 진행 여부 확인 + 예상 시간 표시 |
| | 빈 페이지 | 자동 스킵, 스킵 카운트 결과에 표시 |
| **처리** | OCR 빈 문자열 | 해당 highlight skip + 매핑표에 "OCR 실패" 표시 |
| | 처리 시간 김 (>30초) | 진행률 + 페이지별 인디케이터 + [취소] |
| | 앱 백그라운드 | BG Task로 연장, 진행 상태 SwiftData 저장, 재진입 시 이어서 |
| **출력** | 주황 0개 | 모두 "주제 미지정" 섹션 |
| | 분홍/파랑만 검출 | "추가 메모" 섹션만 + "주요 표시 미감지" 배너 |
| | 검출 영역 0개 | 빈 결과 + [다른 파일 시도] |
| **시스템** | 카메라 권한 거부 | 안내 + [설정 열기] (`openSettingsURLString`) |
| | 저장 공간 부족 | 메모리에서 결과 보여주되 저장 실패 안내 |
| | App Group 접근 실패 | "공유 설정 오류 (Code: AG-01)" + 재시작 권장 |

### 핵심 원칙 3가지

1. **부분 성공 허용**: 12페이지 중 2페이지 실패해도 나머지 출력
2. **데이터 절대 안 잃음**: 원본 App Group 보존, 결과 임시 메모리에라도 표시
3. **막다른 길 금지**: 모든 에러에 안내 + 다음 행동 옵션

### 추가 안전장치

- `didReceiveMemoryWarning` 시 청크 크기 자동 축소
- 모든 에러는 코드(디버깅) + 사용자 친화 문구(UX) 두 가지로
- 변환 결과는 임시저장 → 사용자가 [저장] 누를 때 SwiftData 영속화

---

## 9. 기술 스택 정리

| 영역 | 선택 | 비고 |
|---|---|---|
| 언어 | Swift 5.9+ | 매크로 사용 |
| UI | SwiftUI | iOS 17+ 기능 활용 |
| OCR | Apple Vision Framework | 한국어 인쇄체, 무료, 오프라인 |
| 이미지 처리 | Core Image | HSV 마스킹 |
| PDF 처리 | PDFKit | 페이지 분리, PDF 출력 렌더링 |
| 카메라 스캔 | VNDocumentCameraViewController | 자동 경계·원근·명도 보정 |
| 저장 | SwiftData (iOS 17+) | Note / Page / Highlight |
| 설정 저장 | UserDefaults | ColorRule (Codable JSON) |
| 익스텐션 | Share Extension | App Group + URL Scheme |
| 동시성 | async / await / Actor | OCR 백그라운드 |

---

## 10. 폴더 구조 (제안)

```
Lumark/
├── App/
│   └── LumarkApp.swift           (Entry point, ModelContainer 설정)
├── Models/                       (= JPA Entity)
│   ├── Note.swift
│   ├── Page.swift
│   ├── Highlight.swift
│   ├── ColorCategory.swift
│   └── ColorRule.swift
├── Repositories/                 (= JpaRepository)
│   ├── NoteRepository.swift
│   └── ColorRuleStore.swift
├── Services/                     (= @Service)
│   ├── HighlightDetector.swift   (Core Image HSV)
│   ├── OCRService.swift          (Vision Framework)
│   ├── MarkdownExporter.swift    (도메인 핵심 로직)
│   ├── PDFExporter.swift
│   └── PageRenderer.swift        (PDFKit)
├── ViewModels/                   (= Controller 일부)
│   ├── HomeViewModel.swift
│   ├── ProcessingViewModel.swift
│   └── ResultViewModel.swift
├── Views/                        (= View 레이어)
│   ├── HomeView.swift
│   ├── ProcessingView.swift
│   ├── ResultView.swift
│   ├── SettingsView.swift
│   └── Components/
└── ShareExtension/
    ├── ShareViewController.swift
    └── Info.plist
```

---

## 11. 개발 일정 (Day 단위)

| Day | 작업 | 합격 기준 |
|---|---|---|
| **Day 1** | Xcode 프로젝트 생성, SwiftUI 빈 앱, 이미지 picker | 시뮬레이터에서 사진 1장 선택·표시 |
| **Day 2~4** | **기술 검증 (S1 + S2 + S3)** ⭐ | 위 §7 합격 기준 통과 |
| **Day 5~7** | MVP 통합 (HomeView·ProcessingView·ResultView·SettingsView, SwiftData 연동) | 메인 앱 내 단일 PDF 변환 동작 |
| **Day 8~10** | Share Extension + App Group + URL Scheme | 굿노트에서 공유 → Lumark 결과 화면까지 |
| **Day 11+** | 실사용 + 다듬기 (친구 1~2명 alpha 테스트) | 본인 + 친구 매일 사용 1주 지속 |

### 선결 과제

- [ ] Anthropic API 키 결제 (Claude Code 사용 시)
- [x] Xcode 설치 완료
- [ ] Apple Developer 계정 (실기기 무료 옵션은 v0.1 충분)
- [ ] 굿노트 형광펜 친 PDF 5~10장 테스트 데이터 준비

---

## 12. 우선순위 보호 영역

본인 검사 데이터에 기반한 운영 원칙:

- **창작·표현 활동(블로그·음악)은 protected time**. 이 프로젝트가 진행돼도 일정상 우선 희생 영역 아님.
- **헬스 주 4회 / 동아리 / 사람 만남**은 외향성 107 충족 영역으로 보호.
- **공인중개사 시험 직전 1개월**은 본 프로젝트 의식적 중단. "꾸준함 = 단절 없음"이 아니라 "우선순위에 따라 의식적으로 멈출 줄 아는 것".
- **분기 단위 "선택과 집중" 회고** 시점에 Lumark 진행 상황 점검.

---

## 13. 다음 단계 인수인계

이 문서를 들고:

1. **폴더 선택** → 본인 Mac의 `~/Developer/Lumark` 같은 위치 선택
2. **Xcode → New Project → iOS App** (SwiftUI, SwiftData 옵션 ON)
3. **이 문서를 프로젝트 루트에 `docs/v0.1-spec.md`로 복사**
4. **Day 1 작업 시작**: 빈 SwiftUI 앱 + 이미지 picker
5. **Day 2~4 게이트** 통과 후 MVP 통합 진입

> ※ Claude Code(Xcode 안 통합)나 다음 Cowork 세션에서 이 문서를 첫 입력으로 던지면 즉시 코딩 시작 가능. 모든 결정 사항이 본 문서에 있음.

---

*Lumark v0.1 사양서 끝.*
