//
//  SupabaseConfig.swift
//  Lumark
//
//  Supabase 프로젝트 연결 상수.
//  publishable key + project URL은 RLS로 보호되는 "공개키"라 클라이언트에 박아도 안전.
//  ⚠️ service_role / secret(sb_secret_...) 키는 절대 여기 두지 말 것 — Worker 시크릿 전용.
//

import Foundation

enum SupabaseConfig {
    /// 프로젝트 베이스 URL.
    static let url = URL(string: "https://cjcpbnmjytglultpogeq.supabase.co")!

    /// 공개 publishable 키 (Authorization/apikey 헤더용).
    static let publishableKey = "sb_publishable_i2hNg0RqQca5SjbZ6VCnKQ_eRXLn9oy"

    /// Auth REST 베이스 (`/auth/v1`).
    static var authURL: URL { url.appendingPathComponent("auth/v1") }
}

/// 앱에서 여는 외부 링크.
enum AppLinks {
    /// 개인정보 처리방침·이용약관 URL. docs/privacy-policy.md 내용을 Notion에 게시한 공개 페이지.
    /// 내용 수정 시: Notion 페이지를 편집(재게시 불필요)하고 docs/privacy-policy.md도 함께 갱신.
    static let privacyPolicy = "https://weak-curler-42e.notion.site/Lumark-374e5a0eed5381d195f4fa7a3e2300b4"
}
