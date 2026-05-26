# Lumark

> 형광펜만 그으면, 정리 노트가 알아서 쌓이는 iOS 앱.
> 간호학과 학생을 위한 시험 직전 복습 도구.

| | |
|---|---|
| 버전 | v0.1 (MVP) |
| 타겟 | iOS 17+, SwiftUI, SwiftData |
| 사양서 | [Lumark-v0.1-spec.md](./Lumark-v0.1-spec.md) |
| 아키텍처 | [docs/architecture.md](./docs/architecture.md) |
| 변경 이력 | [CHANGELOG.md](./CHANGELOG.md) |

---

## 한 줄 요약

색깔 = 의미. 노랑은 핵심, 주황은 주제. 굿노트에서 공유로 보내면 OCR을 거쳐 자동으로 마크다운 노트가 쌓입니다.

## v0.1 범위

- 굿노트 PDF · 사진 앱 공유 시트 수신 (Share Extension)
- 메인 앱 picker (PDF/이미지) + 카메라 스캔
- 형광펜 다중 색 검출 (HSV) — 노랑/주황 기본, 분홍/파랑 옵션
- 색별 자동 분류 + 구조 인식 (주황 = 섹션 제목, 노랑 = 글머리표)
- 인쇄체 한국어 OCR (Apple Vision Framework)
- 마크다운 출력 (CommonMark/Obsidian) + PDF 내보내기
- SwiftData 노트 라이브러리 (CRUD, 검색, 정렬, 즐겨찾기)
- 결과 화면: 마크다운 ↔ 원본 PDF 탭, 4색 토글 필터, 복사/공유/PDF 내보내기

## 빌드

```bash
# 시뮬레이터 빌드
xcodebuild -project Lumark.xcodeproj \
  -scheme Lumark \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build

# 단위 테스트
xcodebuild test -project Lumark.xcodeproj \
  -scheme Lumark \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:LumarkTests

# UI 테스트
xcodebuild test -project Lumark.xcodeproj \
  -scheme Lumark \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:LumarkUITests
```

또는 Xcode에서 직접 열기:
```bash
open Lumark.xcodeproj
```

## 앱 아이콘 생성

방향 B (펜 끝 + 4색 스트로크). 3개 variant (light/dark/tinted) 자동 생성:

```bash
swift scripts/generate-app-icon.swift
```

PNG는 `Lumark/Assets.xcassets/AppIcon.appiconset/`에 저장되고 `Contents.json`도 자동 업데이트.

## Share Extension 셋업

코드 파일은 다 준비돼있지만, Xcode UI에서 capability + target 추가가 필요. [docs/share-extension-setup.md](./docs/share-extension-setup.md) 참고.

## 디자인 시스템

`Lumark_design/` 폴더에 HTML/JSX 디자인 시안과 토큰 정의가 있어요. 앱 코드의 `Theme.swift`는 이 토큰을 oklch → sRGB 런타임 변환으로 구현.

## 디렉토리

```
Lumark/
├── App/                  진입점, 라우팅 타입, AppRouter
├── Models/               SwiftData @Model + ColorRule + Mock
├── Repositories/         ColorRuleStore (UserDefaults)
├── Services/             도메인 로직 (AppGroup, Markdown, PDF, Permission, JobState 등)
├── Theme/                디자인 토큰 (oklch → UIColor)
├── ViewModels/           ProcessingViewModel
├── Views/                SwiftUI 화면 + Components/
└── ShareExtension/       Share Extension 코드 (별도 target 필요)

LumarkTests/              Swift Testing 단위 테스트 (32개)
LumarkUITests/            XCUITest UI 테스트 (3개)
docs/                     spec + architecture + setup 가이드
scripts/                  앱 아이콘 생성 등
```

## 개발 일정 (spec §11)

| Day | 작업 | 상태 |
|---|---|---|
| 1 | UI shell + 이미지 picker | ✅ |
| 2~4 | 기술 검증 (HSV / OCR / 구조) | ⏳ 테스트 데이터 대기 |
| 5~7 | MVP 통합 + SwiftData | ✅ |
| 8~10 | Share Extension + App Group + URL Scheme | ✅ 코드, target만 수동 |
| 11+ | 친구 1~2명 alpha 테스트 | ⏳ |

Day 2~4 통과까지는 ProcessingView가 Mock 타이머로 동작합니다. 실제 OCR을 끼우기 전에 ground truth 3장으로 §7 합격선을 측정하는 것이 다음 작업.

## 라이선스

작성자 본인 + 친구들의 학습 자료용. 외부 배포 안 함.

## 작성자

- HG (hyungyugood0129@gmail.com)
- v0.1 작성: 2026-05-21 ~
