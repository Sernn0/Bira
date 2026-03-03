import AppKit
import SwiftUI

/// 말풍선 NSPanel 관리자
/// - 아이콘 오른쪽에 말풍선 패널 표시/숨김
/// - 포커스 이탈 시 자동 닫기
/// - 입력 대기 중 5초 비활성 시 자동 닫기
@MainActor
final class ChatBubblePanel {
    static let shared = ChatBubblePanel()

    private var panel: NSPanel?
    private var appFocusObserver: NSObjectProtocol?
    private var idleTimer: Timer?

    /// 현재 말풍선이 열려있는지 여부
    private(set) var isVisible = false

    private init() {}

    // MARK: - Toggle

    func toggle(relativeTo iconPanel: NSPanel?) {
        if isVisible {
            hide()
        } else {
            show(relativeTo: iconPanel)
        }
    }

    // MARK: - Show

    func show(relativeTo iconPanel: NSPanel?) {
        if panel == nil {
            createPanel()
        }

        positionPanel(relativeTo: iconPanel)
        panel?.orderFront(nil)
        isVisible = true

        startFocusObserver()
        startIdleTimer()
    }

    // MARK: - Hide

    func hide() {
        guard isVisible else { return }
        panel?.orderOut(nil)
        isVisible = false
        stopFocusObserver()
        stopIdleTimer()
    }

    // MARK: - Panel Creation

    private func createPanel() {
        let bubblePanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        bubblePanel.isFloatingPanel = true
        bubblePanel.level = .floating
        bubblePanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        bubblePanel.isOpaque = false
        bubblePanel.backgroundColor = .clear
        bubblePanel.hasShadow = true
        bubblePanel.isMovable = false

        let contentView = ChatBubbleView(onActivity: { [weak self] in
            self?.resetIdleTimer()
        })
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 400)
        bubblePanel.contentView = hostingView

        self.panel = bubblePanel
    }

    // MARK: - Positioning

    /// 아이콘 패널 오른쪽에 8px 여백으로 배치
    private func positionPanel(relativeTo iconPanel: NSPanel?) {
        guard let panel = panel else { return }

        let iconFrame: NSRect
        if let iconPanel = iconPanel {
            iconFrame = iconPanel.frame
        } else {
            // 아이콘 패널 없으면 화면 왼쪽 상단 기준
            let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            iconFrame = NSRect(x: 15, y: screen.maxY - 75, width: 60, height: 60)
        }

        let gap: CGFloat = 8
        let panelSize = panel.frame.size

        // 아이콘 오른쪽에 배치, 아이콘 상단 정렬
        var origin = NSPoint(
            x: iconFrame.maxX + gap,
            y: iconFrame.maxY - panelSize.height
        )

        // 화면 밖으로 나가지 않도록 보정
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            if origin.x + panelSize.width > screenFrame.maxX {
                // 오른쪽 공간이 없으면 왼쪽에 배치
                origin.x = iconFrame.minX - panelSize.width - gap
            }
            origin.y = max(screenFrame.minY, min(origin.y, screenFrame.maxY - panelSize.height))
        }

        panel.setFrameOrigin(origin)
    }

    // MARK: - Focus Observer

    /// 다른 앱으로 포커스 이동 시 말풍선 자동 닫기
    private func startFocusObserver() {
        stopFocusObserver()

        appFocusObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            // Bira 앱이 아닌 다른 앱이 활성화된 경우
            let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let isBira = activatedApp?.bundleIdentifier == Bundle.main.bundleIdentifier
            if !isBira {
                Task { @MainActor in
                    // 결과 출력 후 유지 설정이 꺼진 경우 닫기
                    if !AppSettings.shared.keepOpenAfterOutput {
                        self.hide()
                        OverlayWindowManager.shared.notifyPanelClosed(.chat)
                    }
                }
            }
        }
    }

    private func stopFocusObserver() {
        if let observer = appFocusObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            appFocusObserver = nil
        }
    }

    // MARK: - Idle Timer (5초 비활성 자동 닫기)

    private func startIdleTimer() {
        stopIdleTimer()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
                OverlayWindowManager.shared.notifyPanelClosed(.chat)
            }
        }
    }

    func resetIdleTimer() {
        startIdleTimer()
    }

    private func stopIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
    }
}
