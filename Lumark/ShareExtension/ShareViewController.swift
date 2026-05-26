//
//  ShareViewController.swift
//  Lumark / ShareExtension
//
//  spec §4: Extension은 받은 데이터를 App Group에 저장하고 deeplink만 호출.
//  OCR 등 무거운 처리는 절대 여기서 안 함.
//
//  파일 멤버십:
//  - 이 파일: ShareExtension target only
//  - AppGroup.swift, URLSchemeRouter.swift: 두 target 모두 (Target Membership 체크)
//  - Theme.swift: ShareExtension target에도 포함 (디자인 토큰 공유)
//

import UIKit
import Social
import UniformTypeIdentifiers
import SwiftUI

/// SwiftUI ShareView를 호스팅하는 Extension 진입점.
class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // SwiftUI View로 위임
        let host = UIHostingController(rootView: ShareView(
            inputs: gatherInputs(),
            onConvert: { [weak self] result in
                self?.handleConvert(result: result)
            },
            onCancel: { [weak self] in
                self?.completeAndDismiss(success: false)
            }
        ))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    // MARK: - 입력 수집

    private func gatherInputs() -> [ShareInput] {
        guard let extensionContext,
              let items = extensionContext.inputItems as? [NSExtensionItem] else { return [] }
        var inputs: [ShareInput] = []
        for item in items {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                    inputs.append(.pdf(provider))
                } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    inputs.append(.image(provider))
                }
            }
        }
        return inputs
    }

    // MARK: - 변환 처리

    private func handleConvert(result: Result<[UUID], Error>) {
        switch result {
        case .success(let ids):
            // 받은 inbox ID 중 첫 항목으로 deeplink — v0.1은 단일 항목만 처리
            guard let firstID = ids.first,
                  let url = LumarkDeeplink.importInbox(id: firstID).toURL() else {
                completeAndDismiss(success: false)
                return
            }
            openMainApp(url: url)
        case .failure:
            completeAndDismiss(success: false)
        }
    }

    /// 메인 앱을 deeplink로 호출. Extension API는 직접 openURL을 막아두므로
    /// responder chain을 타고 올라가서 호출.
    private func openMainApp(url: URL) {
        var responder: UIResponder? = self
        let selector = sel_registerName("openURL:")
        while let r = responder {
            if r.responds(to: selector) {
                _ = r.perform(selector, with: url)
                break
            }
            responder = r.next
        }
        completeAndDismiss(success: true)
    }

    private func completeAndDismiss(success: Bool) {
        if success {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        } else {
            extensionContext?.cancelRequest(withError: NSError(
                domain: "ShareExtension", code: 1, userInfo: nil
            ))
        }
    }
}

// MARK: - 입력 타입

enum ShareInput: Identifiable {
    case pdf(NSItemProvider)
    case image(NSItemProvider)

    var id: ObjectIdentifier {
        switch self {
        case .pdf(let p):   return ObjectIdentifier(p)
        case .image(let p): return ObjectIdentifier(p)
        }
    }

    var isPDF: Bool {
        if case .pdf = self { return true }
        return false
    }

    var provider: NSItemProvider {
        switch self {
        case .pdf(let p), .image(let p): return p
        }
    }
}
