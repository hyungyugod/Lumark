# Share Extension 셋업 가이드

코드 파일은 모두 준비돼있어요. Xcode에서 수동으로 처리해야 하는 단계만 정리.

## 1. App Group capability (메인 앱)

1. Xcode에서 프로젝트 선택 → **Lumark** target → **Signing & Capabilities**
2. `+ Capability` → **App Groups** 추가
3. `+` 버튼으로 그룹 ID 추가: `group.com.lumark`
4. 체크 ✅

## 2. URL Scheme 등록 (메인 앱)

`GENERATE_INFOPLIST_FILE = YES` 라서 Build Settings로 처리해야 함:

1. Lumark target → **Build Settings** → 검색: `Info.plist`
2. 또는 더 깔끔히, Info.plist 파일을 생성해서 관리하기:
   - 새 파일 → iOS → Property List → 이름 `Info.plist`, Lumark target에 추가
   - Build Settings의 `Generate Info.plist File` → **NO**
   - `Info.plist File` → `Lumark/Info.plist`
3. Info.plist에 다음 추가:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.lumark.deeplink</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>lumark</string>
        </array>
    </dict>
</array>
```

또는 Xcode UI에서 Lumark target → Info → URL Types → `+`:
- Identifier: `com.lumark.deeplink`
- URL Schemes: `lumark`

## 3. ShareExtension Target 생성

1. File → New → Target → iOS → **Share Extension**
2. Product Name: `LumarkShareExtension`
3. Bundle Identifier: `com.hyungyu.Lumark.ShareExtension` (메인 앱 ID 뒤에 .ShareExtension)
4. Language: Swift
5. Embed in Application: `Lumark` ✓

Xcode가 자동으로 `LumarkShareExtension/ShareViewController.swift` 와 `Info.plist` 생성. 자동 생성된 ShareViewController.swift는 **삭제**.

## 4. ShareExtension 파일 구성

자동 생성된 폴더(`LumarkShareExtension`)는 두고, 이 프로젝트의 `Lumark/ShareExtension/` 폴더에 있는 파일들을 ShareExtension target에 포함:

- `Lumark/ShareExtension/ShareViewController.swift` → ShareExtension target 추가
- `Lumark/ShareExtension/ShareView.swift` → ShareExtension target 추가

자동 생성된 `LumarkShareExtension/Info.plist`에 다음 항목 확인/수정:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <dict>
            <key>NSExtensionActivationSupportsFileWithMaxCount</key>
            <integer>10</integer>
            <key>NSExtensionActivationSupportsImageWithMaxCount</key>
            <integer>10</integer>
        </dict>
    </dict>
    <key>NSExtensionMainStoryboard</key>  <!-- 삭제 -->
    <key>NSExtensionPrincipalClass</key>   <!-- 추가 -->
    <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
</dict>
```

핵심: `NSExtensionMainStoryboard` 제거하고 `NSExtensionPrincipalClass`를 우리 SwiftUI 기반 ShareViewController로.

또 자동 생성된 `MainInterface.storyboard`는 **삭제** (SwiftUI 기반이라 안 씀).

## 5. ShareExtension에도 App Group capability

ShareExtension target → Signing & Capabilities → App Groups → 메인 앱과 **동일한 `group.com.lumark`** 체크.

## 6. 공유 파일 Target Membership

ShareExtension은 메인 앱의 다음 파일들이 필요해서, 양쪽 target에 모두 포함:

- `Lumark/Services/AppGroup.swift`
- `Lumark/Services/URLSchemeRouter.swift`
- `Lumark/Theme/Theme.swift`
- `Lumark/Models/ColorCategory.swift`

각 파일 → File Inspector → Target Membership → **ShareExtension** 체크 추가 (메인 Lumark는 그대로).

## 7. 검증 동선

1. 시뮬레이터에서 빌드/실행 → 홈 화면 확인
2. 사진 앱 또는 Files 앱 열기 → 임의 PDF/사진 선택 → 공유 → "Lumark" 보이면 ✅
3. Lumark 선택 → ShareView가 뜸 → [변환 시작]
4. 자동으로 메인 앱이 열리면서 ProcessingView 진입 → ResultView까지 가야 ✅

## 8. 흔한 트러블슈팅

- **"Lumark"가 공유 시트에 안 보임**: ShareExtension Info.plist의 ActivationRule 확인
- **메인 앱이 deeplink 받았을 때 아무 일도 안 일어남**: URL Scheme 등록 확인 + Console에서 `LumarkDeeplink.parse` 로그
- **App Group 접근 실패 (AG-01)**: 양쪽 target 모두 동일한 group ID 추가 확인
- **SwiftUI Hosting에서 화면 안 보임**: `addChild` → `view.addSubview` → `didMove(toParent:)` 순서 확인

---

코드 파일들은 다 준비됐어요. 위 단계만 Xcode에서 처리하면 spec §4 전체가 동작합니다.
