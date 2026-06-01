# 카카오 로그인 설정 가이드

앱 코드는 완료(`AuthManager.signInWithKakao`, SignInView 버튼). 활성화하려면 아래 3곳 설정 필요.
로그인 자체는 **무료**(카카오 로그인 API는 과금 없음).

## 1. 카카오 개발자 — 앱 등록
1. https://developers.kakao.com → 로그인 → **내 애플리케이션 → 애플리케이션 추가하기**
   (앱 이름 "Lumark", 사업자명 본인)
2. **앱 키**에서 **REST API 키** 복사 (Supabase에 넣을 값)
3. **카카오 로그인** 메뉴 → **활성화 설정 ON**
4. **Redirect URI** 등록:
   ```
   https://cjcpbnmjytglultpogeq.supabase.co/auth/v1/callback
   ```
5. **동의항목** → 닉네임/프로필 사진(필수 X여도 됨), **카카오계정(이메일)**을 선택 동의로 받도록 설정
   (이메일을 받아야 Supabase가 user 이메일을 채움 — 없어도 로그인은 되지만 이메일 빈 값)
6. (보안) **Client Secret** → 코드 생성 후 **활성화 상태 ON** → 그 secret 복사

## 2. Supabase — Kakao provider
대시보드 → **Authentication → Providers → Kakao**:
1. **Enable** 토글 ON
2. **REST API Key** = 1번에서 복사한 카카오 REST API 키
3. **Client Secret** = 1번 6에서 만든 secret (Supabase가 요구하면)
4. Save

## 3. Supabase — Redirect URLs 허용목록
대시보드 → **Authentication → URL Configuration → Redirect URLs**에 추가:
```
lumark://login-callback
```
(앱이 OAuth 후 돌아올 주소. 없으면 "redirect not allowed" 에러.)

## 테스트
앱(실기기 권장) → 로그인 화면 → **카카오로 로그인** → 카카오 웹 로그인 →
돌아와서 "크레딧 200" 뜨면 성공. Supabase Table Editor `profiles`에 행 생성 확인.

## 참고
- 카카오는 Apple처럼 네이티브가 아니라 **웹 OAuth**(브라우저 잠깐 열림). 정상.
- 버튼 디자인: 현재 SF Symbol 말풍선 + "카카오로 로그인". 출시 전 카카오 공식 로고/문구
  가이드(developers.kakao.com/docs/latest/ko/kakaologin/design-guide)에 맞춰 교체 권장.
- 다중 provider(Apple+Kakao) → 한 사람이 두 계정 = 무료 크레딧 2배 가능. 남용 보이면
  global cap/크레딧 조정 또는 이메일로 identity linking 고려.
