# Lumark 백엔드 계획서 — 계정 + 크레딧 (Supabase)

> 상태: **제안(draft) — 코드 미구현.** 작성 2026-05-28. 검토 후 §13 결정사항을 정하면 구현 시작.

## 1. 목표
- 무료 키리스 프록시(`lumark-ocr-proxy`)의 **비용 통제**가 핵심 동기.
- 계정 로그인 → 계정별 **크레딧** → 정리본/퀴즈 생성 시 차감 → 공정·제한적 무료 사용.
- **1인 1계정** 지향(완벽 강제는 아님, 현실적 상한).
- 더 쓰려면 **본인 Gemini 키**(무제한, 프록시 우회) — *이미 구현됨*.

## 2. 현재 아키텍처 (변경 전)
- iOS(SwiftData) → CF Worker `lumark-ocr-proxy` → **AI Gateway** → Gemini.
- Worker: KV(RATE) 기기당/전체 일일 한도, `APP_TOKEN` 헤더 게이트, `GEMINI_KEY` 시크릿.
- 식별: 익명 `X-Device-ID`(위조 가능) → 그래서 계정이 필요.
- **AI Gateway 경유가 핵심**: Worker 직접 egress가 Gemini 미지원 리전("User location not supported")으로 잡히는 문제를 우회. → **이 Worker는 유지하는 게 안전**(아래 Path 선택의 전제).

## 3. 아키텍처 결정 (가장 중요)

### Path A — Supabase(인증+크레딧) + Worker(프록시) 유지 ✅ 추천
- Supabase가 잘하는 것(Auth, Postgres, RLS, 대시보드) + Worker가 잘하는 것(AI Gateway 경유 Gemini) 분리.
- 앱이 Supabase Auth로 로그인 → JWT. Worker 호출 시 JWT 동봉. Worker가 JWKS로 검증 후 크레딧 차감 → Gemini.
- 장점: 인증을 직접 안 만듦, Postgres+RLS+대시보드로 빠른 개발.
- 단점: 백엔드 2개, 요청마다 Worker→Supabase 왕복(수십 ms). **무료 플랜 1주 미사용 시 일시정지**(2026-02 강화) — 초기 트래픽 적으면 걸림.

### Path B — 전부 Cloudflare (Supabase 없음)
- Sign in with Apple를 Worker에서 직접 검증(Apple JWKS) → 자체 세션 토큰 발급. 크레딧은 D1(SQLite).
- 장점: 단일 벤더, 최저 지연, 일시정지 없음, Worker가 이미 있음.
- 단점: 세션 발급/갱신·관리 도구를 직접 구현. RLS/대시보드 없음.

**추천: Path A.** 인증이 가장 손 많이 가는데 Supabase가 대신해주고, 본인이 Supabase 선호. 단 1주 일시정지 gotcha만 인지(§11). 나중에 지연/비용이 문제면 Path B로 이전 가능(크레딧 로직은 거의 동일).

## 4. 제안 아키텍처 (Path A)
```
[iOS 앱]
  │  ① Sign in with Apple (supabase-swift) → Supabase Auth → user JWT
  │
  ├─ (Lumark Cloud 경로) ② POST /ocr,/quiz  + Authorization: Bearer <JWT>
  │        ↓
  │   [CF Worker]  ③ JWKS로 JWT 검증 (sub = userId)
  │        │       ④ Supabase RPC spend_credits(userId, cost)  ← service_role
  │        │            ├ 잔액 부족 → 402 (차감 안 함)
  │        │            └ 차감 성공(예약)
  │        │       ⑤ AI Gateway → Gemini
  │        │            └ 실패 시 refund_credits (환불)
  │        └──────→ 결과(spans/cards) 반환
  │
  └─ (본인 키 경로) 앱 → Gemini 직접 (Worker/크레딧 무관, 무제한)

[Supabase]  Auth(Apple) + Postgres(profiles, credit_ledger) + RLS + RPC
```

## 5. Supabase 설계
**테이블**
- `profiles`: `id uuid PK (= auth.users.id)`, `credits int`, `plan text default 'free'`, `created_at`.
- `credit_ledger`: `id, user_id, delta int, reason text, ref text, created_at` (감사·환불 추적).

**가입 시 무료 크레딧**: `auth.users` insert 트리거 → profiles 생성 + 초기 크레딧 + 원장 기록.

**RLS**: 사용자는 본인 `profiles`/`credit_ledger` **SELECT만**. 쓰기는 전부 service_role(RPC)로만.

**RPC (원자적 — 레이스 없음)**
```sql
-- 예약: 잔액 >= cost 면 한 UPDATE로 차감. 부족하면 -1.
create function spend_credits(p_user uuid, p_amount int, p_reason text, p_ref text)
returns int language plpgsql security definer as $$
declare new_bal int;
begin
  update profiles set credits = credits - p_amount
   where id = p_user and credits >= p_amount
   returning credits into new_bal;
  if new_bal is null then return -1; end if;
  insert into credit_ledger(user_id, delta, reason, ref)
       values (p_user, -p_amount, p_reason, p_ref);
  return new_bal;
end $$;
-- refund_credits(...): Gemini 실패 시 credits = credits + p_amount (+ 원장 +delta)
-- 실행권한: service_role 만. revoke from anon, authenticated.
```

**월 무료 충전(선택)**: pg_cron으로 매월 무료 한도 충전, 또는 "마지막 충전일" 기준 lazy 충전.

## 6. Worker 변경
- `Authorization: Bearer <JWT>` 검증: JWKS `https://<ref>.supabase.co/auth/v1/.well-known/jwks.json` 가져와 캐시(10분), `kid`로 키 선택, 서명+exp+iss+aud 확인(`jose` 등). `sub` = userId.
- 크레딧: cost 계산(OCR=페이지수, quiz=고정) → `spend_credits`(service_role 키=Worker 시크릿). -1이면 **402** `{error:"크레딧 부족"}`(Gemini 호출 안 함).
- **예약→호출→실패 시 환불** 패턴으로 동시성 안전. (먼저 차감, Gemini 실패하면 `refund_credits`.)
- AI Gateway 경유 유지.
- `APP_TOKEN`/`X-Device-ID` + KV 일일한도: JWT/크레딧이 대체 → **제거 가능**(원하면 APP_TOKEN은 방어층으로 유지). GLOBAL_DAILY는 backstop으로 유지 권장.
- 새 시크릿: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (**절대 앱에 넣지 말 것**).

## 7. iOS 앱 변경
- 패키지: `supabase-swift`(SPM).
- **로그인 화면**: Sign in with Apple(AuthenticationServices)로 idToken+nonce → `supabase.auth.signInWithIdToken(.init(provider:.apple, idToken:, nonce:))`. (Apple 토큰엔 이름이 없어 첫 로그인 시 클라에서 캡처해 저장.)
- 세션: supabase-swift가 Keychain 저장/자동 갱신.
- OCR/퀴즈 호출에 Bearer JWT 동봉 — `ProxyOCRProvider`/`ProxyQuizProvider`의 deviceID/appToken 자리를 토큰으로 교체.
- 메인/설정에 **크레딧 잔액 표시**(profiles SELECT, RLS로 본인 것만).
- **402(크레딧 부족) 처리**: `LumarkError` 케이스 추가 → "본인 키 쓰기" / "내일 다시" 유도.
- 엔터틀먼트: Sign in with Apple capability + Apple Developer App ID + Supabase Apple provider(Services ID/Key) 설정.

## 8. 크레딧 정책 (제안 — 전부 튜닝 가능)
| 동작 | 크레딧 | 비고 |
|---|---|---|
| 정리본(OCR) | 페이지당 1 | 1회 변환 최대 20p → 최대 20 |
| 퀴즈 생성 | 회당 2 | 텍스트 1콜 |
| 본인 키 사용 | 0 | 프록시 우회 = 무제한 |

- 무료: 가입 시 + **매월 100 크레딧**(≈ 100페이지 또는 퀴즈 50회).
- 실제 Gemini 원가는 매우 낮음(Flash Lite ≈ 페이지당 $0.0004) → 크레딧은 **원가 회수가 아니라 남용·공정성 상한**.
- 유료 충전(StoreKit IAP): **보류**(수요 생기면). 우선 무료한도 + 본인키.

## 9. 1인 1계정 / 남용 방지
- Apple ID당 1 user(Supabase가 `sub`로 dedup) — 현실적 상한(완벽X, 한 사람 여러 Apple ID 가능).
- **남용 벡터 = 무료 크레딧 노린 다계정.** 완화: 무료 한도 과하지 않게 / Worker `GLOBAL_DAILY` backstop / device-id를 보조 탐지 신호로 기록 / 정 필요하면 전화 인증(SMS 비용·마찰, v1 비권장).

## 10. 보안 / 프라이버시
- `service_role` 키는 **Worker 시크릿에만**. 앱엔 anon 키 + 사용자 JWT만.
- RLS로 본인 데이터만 read, 크레딧 쓰기는 RPC(service_role)만.
- PII 최소(Apple relay 이메일/sub). spec §8 데이터 보호 기조 유지.

## 11. 비용 / 운영 (2026 기준)
- Supabase 무료: DB 500MB · 스토리지 1GB · **50,000 MAU** · 무제한 API. 초기 충분.
- ⚠️ **무료 프로젝트는 1주 미사용 시 일시정지**(2026-02 강화). 초기 트래픽 적으면 걸림 → 외부 cron 핑 또는 Pro($25/mo).
- Cloudflare: Worker/D1/KV 무료 한도로 충분.

## 12. 단계별 로드맵 (대략 3~4일, UI와 독립)
- **P0 Supabase 셋업** — 프로젝트, Apple provider, 스키마+RLS+RPC+가입 트리거. (~반일)
- **P1 앱 로그인** — supabase-swift, Sign in with Apple, 로그인 화면, 세션. (~1일)
- **P2 Worker 통합** — JWT 검증(JWKS), spend/refund 연동, 402. (~1일)
- **P3 크레딧 UX** — 잔액 표시, 부족 안내, 본인키 유도. (~반일)
- **P4 정리/롤아웃** — device-token 경로 정리, 월 충전(cron), 검증. (~반일)

## 13. 확정된 결정 (2026-05-28)
1. 아키텍처: **Path A** (Supabase 인증+크레딧 + 기존 Worker 프록시 유지).
2. 인증: **Sign in with Apple만.**
3. 로그인 범위: **Lumark Cloud 쓸 때만.** 본인 키·Apple Vision은 로그인 없이 익명 사용.
4. 크레딧: **가입 + 매월 무료 100**, OCR **1/페이지**, 퀴즈 **2/회**, 본인 키 **무제한**.
5. 유료 충전(IAP): **없음** (현역 군 복무 중 수익 불가 — 전역 후 이 크레딧 위에 얹는 건 구조상 가능).
6. 1인 1계정: Apple ID 기준(현실적 상한). 전화 인증은 남용 관찰되면 추후.

> 역할 분담: 코드(SQL/Worker/iOS)는 Claude 작성. Supabase 프로젝트 생성·Apple Developer 설정·배포·시크릿은 사용자(계정 생성 불가). `service_role` 키는 Worker 시크릿에만(앱 금지).

## 14. 리스크
- Supabase 1주 일시정지(초기) → cron 핑/Pro.
- Worker→Supabase 왕복 지연 → 심하면 Path B.
- 무료 크레딧 다계정 남용 → 한도/글로벌캡/탐지.
- Apple 토큰엔 이름 없음 → 첫 로그인 시 클라에서 캡처.
- 전환: 기존 노트는 기기 로컬(SwiftData)이라 로그인 도입과 무관(영향 없음).

## 참고 링크
- Supabase JWT signing keys / 검증: https://supabase.com/docs/guides/auth/signing-keys , https://supabase.com/docs/guides/auth/jwts
- Swift Sign in with Apple: https://supabase.com/docs/guides/auth/social-login/auth-apple , https://supabase.com/docs/reference/swift/auth-signinwithidtoken
- Pricing/무료 한도: https://supabase.com/pricing
