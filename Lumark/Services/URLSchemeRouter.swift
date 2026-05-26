//
//  URLSchemeRouter.swift
//  Lumark
//
//  lumark:// URL 파싱. Share Extension → 메인 앱 진입 경로의 deeplink.
//

import Foundation

enum LumarkDeeplink: Equatable, Sendable {
    /// lumark://import?id={uuid}
    case importInbox(id: UUID)

    nonisolated static func parse(_ url: URL) -> LumarkDeeplink? {
        guard url.scheme?.lowercased() == "lumark" else { return nil }

        let host = url.host?.lowercased() ?? ""
        switch host {
        case "import":
            guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let idStr = comps.queryItems?.first(where: { $0.name == "id" })?.value,
                  let id = UUID(uuidString: idStr)
            else { return nil }
            return .importInbox(id: id)
        default:
            return nil
        }
    }

    /// 빌드 — Share Extension에서 메인 앱 호출 시 사용.
    nonisolated func toURL() -> URL? {
        switch self {
        case .importInbox(let id):
            var comps = URLComponents()
            comps.scheme = "lumark"
            comps.host = "import"
            comps.queryItems = [URLQueryItem(name: "id", value: id.uuidString)]
            return comps.url
        }
    }
}
