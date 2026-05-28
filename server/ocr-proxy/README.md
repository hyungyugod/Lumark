# Lumark OCR Proxy (Cloudflare Worker)

Gemini API 키를 앱에 넣지 않고 서버가 대신 호출한다. 기기당/전체 일일 페이지
한도로 비용 폭주를 막는다. Cloudflare Workers 무료 티어 (카드 등록 불필요,
하루 10만 요청)로 충분하다.

## 한 번만 배포 (약 15분)

### 0. 사전 준비
- Cloudflare 계정 (무료): https://dash.cloudflare.com/sign-up
- Node.js 설치 (`node -v`로 확인, 없으면 https://nodejs.org)

### 1. 이 디렉토리에서 wrangler 로그인
```bash
cd server/ocr-proxy
npx wrangler login
```
브라우저가 열리면 Cloudflare 로그인 → 권한 허용.

### 2. KV 네임스페이스 생성 (일일 카운터 저장소)
```bash
npx wrangler kv namespace create RATE
```
출력에 나오는 `id = "..."` 값을 복사해서 `wrangler.toml`의
`PASTE_KV_NAMESPACE_ID_HERE` 자리에 붙여넣는다.

### 3. Gemini 키를 secret으로 등록 (앱엔 안 들어감)
```bash
npx wrangler secret put GEMINI_KEY
```
프롬프트에 Google AI Studio 키(AIza...) 붙여넣고 엔터.

### 4. 배포
```bash
npx wrangler deploy
```
성공하면 `https://lumark-ocr-proxy.<your-subdomain>.workers.dev` 같은 URL이
출력된다. **이 URL을 복사.**

### 5. 앱에 URL 연결
`Lumark/Services/OCRPreferences.swift`의 `lumarkCloudEndpoint` 상수를
방금 받은 URL + `/ocr` 로 교체:
```swift
static let lumarkCloudEndpoint = "https://lumark-ocr-proxy.<your-subdomain>.workers.dev/ocr"
```
앱 빌드 → 설정 → OCR 엔진 → "Lumark Cloud" 선택. 키 입력 없이 동작.

## 비용 한도 조정

`wrangler.toml`의 vars로 제어 (수정 후 `npx wrangler deploy` 재실행):
- `PER_DEVICE_DAILY` — 기기당 하루 페이지 수 (기본 60)
- `GLOBAL_DAILY` — 전체 하루 페이지 수 (기본 1500) ← 청구서 상한의 핵심
- `MODEL` — Gemini 모델 (기본 gemini-2.5-flash-lite)

전체 1500p/일 = Flash Lite 기준 하루 약 $0.6, 월 약 $18. 월 5만원 한참 아래.
친구가 늘면 GLOBAL_DAILY를 보고 조절.

## 사용량 확인
Cloudflare 대시보드 → Workers → lumark-ocr-proxy → Metrics.
Gemini 사용량은 Google AI Studio → Usage.

## 로컬 테스트 (선택)
```bash
npx wrangler dev
# 다른 터미널에서:
curl -X POST http://localhost:8787/ocr \
  -H "X-Device-ID: test-device-1234" \
  -H "Content-Type: application/json" \
  -d '{"image_base64":"<base64 jpeg>"}'
```
