//
//  SignInView.swift
//  Lumark
//
//  Lumark Cloud(무료 크레딧) 사용 시 띄우는 로그인 화면. Sign in with Apple만.
//  본인 키·Apple Vision은 로그인 없이 쓸 수 있으므로 "나중에" 로 닫을 수 있음.
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @State private var auth = AuthManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    /// 로그인 성공 시 호출(시트 닫기 등). nil이면 자동 dismiss.
    var onSignedIn: (() -> Void)?
    /// 설정되면 "런치 게이트" 모드 — 건너뛰기가 게스트 진입(dismiss 대신 이걸 호출).
    var onContinueAsGuest: (() -> Void)?

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            VStack(spacing: Space.s4) {
                Spacer()

                LumarkWordmark(size: 36)

                VStack(spacing: 10) {
                    Text("로그인하고 무료 크레딧 받기")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text("Lumark Cloud로 정리본·퀴즈를 만들려면 로그인이 필요해요.\n가입하면 매달 무료 크레딧이 충전돼요.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(Palette.subtle)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 12) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = auth.prepareNonce()
                    } onCompletion: { result in
                        Task {
                            await auth.completeAppleSignIn(result)
                            if auth.isSignedIn {
                                // 게이트 모드: 루트가 auth 상태를 보고 자동 전환. 시트 모드: 닫기.
                                if onContinueAsGuest == nil { onSignedIn?() ?? dismiss() }
                                else { onSignedIn?() }
                            }
                        }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                    .clipShape(Capsule())

                    // 카카오 로그인 (한국 사용자 편의). 웹 OAuth.
                    Button {
                        Task {
                            await auth.signInWithKakao()
                            if auth.isSignedIn {
                                if onContinueAsGuest == nil { onSignedIn?() ?? dismiss() }
                                else { onSignedIn?() }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 16))
                            Text("카카오로 로그인")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(Color(red: 0.23, green: 0.19, blue: 0.13)) // 카카오 다크 텍스트
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Capsule().fill(Color(red: 1.0, green: 0.898, blue: 0.0))) // #FEE500
                    }
                    .buttonStyle(.plain)

                    if let err = auth.errorMessage {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        if let onContinueAsGuest { onContinueAsGuest() } else { dismiss() }
                    } label: {
                        Text(onContinueAsGuest != nil ? "로그인 없이 둘러보기" : "나중에 — 본인 키로 쓸게요")
                            .font(.system(size: 13.5))
                            .foregroundStyle(Palette.brown)
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 28)

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                    Text("Apple 또는 카카오로 로그인해요. 노트는 기기에 저장되고, 사용량 관리에만 계정을 써요.")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.subtle)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, Space.s5)
            }

            if auth.isWorking {
                ZStack {
                    Color.black.opacity(0.18).ignoresSafeArea()
                    ProgressView("로그인 중…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

#Preview {
    SignInView()
}
