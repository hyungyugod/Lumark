//
//  Supa.swift
//  Lumark
//
//  앱 전역 Supabase 클라이언트 (인증 + DB).
//  publishable key + URL은 공개키라 클라이언트에 박아도 안전(RLS로 보호).
//

import Foundation
import Supabase

enum Supa {
    static let client = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.publishableKey
    )
}
