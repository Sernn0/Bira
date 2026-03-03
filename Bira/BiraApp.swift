//
//  BiraApp.swift
//  Bira
//
//  Created by 윤여명 on 3/3/26.
//

import SwiftUI
import AppKit

@main
struct BiraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // NSPanel 기반이므로 SwiftUI Scene은 비움
        // 실제 UI는 AppDelegate에서 NSPanel/NSWindow로 직접 관리
        Settings {
            EmptyView()
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 독(Dock) 아이콘 숨기기 — 오버레이 앱이므로
        NSApp.setActivationPolicy(.accessory)

        Task { @MainActor in
            if AppSettings.shared.onboardingSeen {
                // 온보딩 완료 → 오버레이 바로 시작
                OverlayWindowManager.shared.setup()
            } else {
                // 최초 실행 → 온보딩 표시
                OnboardingWindowManager.shared.show()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        OverlayWindowManager.shared.removeHotKey()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 온보딩 창이 닫혀도 앱 유지 (오버레이가 살아있으므로)
        return false
    }
}

