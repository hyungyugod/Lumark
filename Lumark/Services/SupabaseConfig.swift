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
