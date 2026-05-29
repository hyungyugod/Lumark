//
//  AuthManager.swift
//  Lumark
//
//  로그인 상태 + Sign in with Apple → Supabase 세션.
//  로그인은 Lumark Cloud(서버 비용 경로)를 쓸 때만 필요. 본인 키·Apple Vision은 익명.
//
//  Apple 로그인 흐름:
//    1) 요청 전 nonce 생성 → raw는 보관, sha256(raw)를 Apple 요청에 첨부
//    2) Apple이 idToken 발급 → Supabase signInWithIdToken(.apple, idToken, nonce=raw)
//    3) Supabase가 토큰 검증 후 세션 발급(+신규면 profiles 트리거로 100크레딧)
//

import Foundation
import AuthenticationServices
import CryptoKit
import Supabase

@MainActor
@Observable
final class AuthManager {
    static let shared = AuthManager()

    private(set) var session: Session?
    private(set) var isWorking = false
    /// 현재 크레딧 잔액(profiles에서 읽거나 Worker 응답으로 갱신). 미조회면 nil.
    private(set) var credits: Int?
    var errorMessage: String?

    /// 현재 Apple 요청에 쓰인 raw nonce (검증용으로 Supabase에 전달).
    private var currentNonce: String?

    var isSignedIn: Bool { session != nil }
    var userID: UUID? { session?.user.id }
    var email: String? { session?.user.email }

    private init() {
        session = Supa.client.auth.currentSession
        Task { await observe() }
    }

    /// 세션 변동(자동 갱신/로그아웃 등)을 반영. 로그인되면 크레딧도 갱신.
    private func observe() async {
        for await change in Supa.client.auth.authStateChanges {
            session = change.session
            if session != nil { await refreshCredits() } else { credits = nil }
        }
    }

    /// Worker 호출용 신선한 JWT. 만료됐으면 SDK가 자동 갱신해서 돌려줌. 없으면 nil.
    func freshAccessToken() async -> String? {
        try? await Supa.client.auth.session.accessToken
    }

    /// profiles에서 본인 크레딧 조회(RLS로 본인 행만). 실패는 조용히 무시.
    func refreshCredits() async {
        guard let uid = userID else { credits = nil; return }
        struct Row: Decodable { let credits: Int }
        do {
            let row: Row = try await Supa.client
                .from("profiles")
                .select("credits")
                .eq("id", value: uid.uuidString)
                .single()
                .execute()
                .value
            credits = row.credits
        } catch {
            // 네트워크/일시정지 등 — 기존 값 유지
        }
    }

    /// Worker 응답이 알려준 최신 잔액을 즉시 반영(라운드트립 없이).
    func setCreditsFromServer(_ n: Int) { credits = n }

    // MARK: - Apple 로그인

    /// Apple 요청 직전 호출 — raw nonce 저장하고 해시를 반환(요청 `.nonce`에 넣음).
    func prepareNonce() -> String {
        let raw = Self.randomNonceString()
        currentNonce = raw
        return Self.sha256(raw)
    }

    /// SignInWithAppleButton onCompletion 결과 처리.
    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        errorMessage = nil
        switch result {
        case .failure(let error):
            // 사용자가 취소한 경우는 조용히 무시.
            if let e = error as? ASAuthorizationError, e.code == .canceled { return }
            errorMessage = "Apple 로그인 실패: \(error.localizedDescription)"

        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = "Apple 자격 증명을 읽지 못했어요."
                return
            }
            guard let nonce = currentNonce else {
                errorMessage = "로그인 정보가 만료됐어요. 다시 시도해주세요."
                return
            }

            isWorking = true
            defer { isWorking = false }
            do {
                let s = try await Supa.client.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
                )
                session = s
                await refreshCredits()
            } catch {
                errorMessage = "로그인 처리 실패: \(error.localizedDescription)"
            }
        }
    }

    func signOut() async {
        try? await Supa.client.auth.signOut()
        session = nil
    }

    // MARK: - nonce helpers

    private static func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
