import AppKit
import SwiftUI

// MARK: - 오버레이 UI 상태

/// 현재 화면에 표시 중인 패널 종류
enum OverlayPanel {
    case chat
    case history
    case palette
    case none
}

// MARK: - OverlayWindowManager

/// NSPanel 기반 오버레이 창 관리자
/// - 한 번에 하나의 패널만 표시
/// - 같은 패널을 다시 요청하면 토글(닫기)
@MainActor
final class OverlayWindowManager {
    static let shared = OverlayWindowManager()

    private var iconPanel: NSPanel?
    private var hotKeyMonitor: Any?

    /// 현재 열려 있는 패널
    private(set) var currentPanel: OverlayPanel = .none

    private init() {}

    // MARK: - Setup

    func setup() {
        createIconPanel()
        registerHotKey()
        applyPosition()
        iconPanel?.orderFront(nil)
    }

    // MARK: - Panel Creation

    private func createIconPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 60, height: 60),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = AppSettings.shared.showOverFullscreen ? .screenSaver : .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.isMovable = false

        let hostingView = IconHostingView(rootView: CharacterIconView())
        hostingView.frame = NSRect(x: 0, y: 0, width: 60, height: 60)
        panel.contentView = hostingView

        self.iconPanel = panel
    }

    // MARK: - 중앙 패널 표시 로직

    /// 요청한 패널이 이미 열려 있으면 닫고, 아니면 기존 패널을 닫고 새 패널을 연다.
    private func showPanel(_ panel: OverlayPanel) {
        if currentPanel == panel {
            // 같은 패널 → 토글(닫기)
            closeCurrentPanel()
            return
        }
        // 다른 패널이 열려 있으면 먼저 닫기
        closeCurrentPanel()

        // 새 패널 열기
        currentPanel = panel
        switch panel {
        case .chat:
            ChatBubblePanel.shared.show(relativeTo: iconPanel)
        case .history:
            SessionHistoryPanel.shared.show(relativeTo: iconPanel)
        case .palette:
            guard let p = iconPanel else { return }
            PaletteMenuCoordinator.shared.show(relativeTo: p)
        case .none:
            break
        }
    }

    /// 현재 열려 있는 패널을 닫는다.
    func closeCurrentPanel() {
        switch currentPanel {
        case .chat:    ChatBubblePanel.shared.hide()
        case .history: SessionHistoryPanel.shared.hide()
        case .palette: PaletteMenuCoordinator.shared.hide()
        case .none:    break
        }
        currentPanel = .none
    }

    /// 패널이 외부(포커스 이탈 등)에 의해 닫혔을 때 상태만 리셋한다. (순환 방지용)
    func notifyPanelClosed(_ panel: OverlayPanel) {
        if currentPanel == panel {
            currentPanel = .none
        }
    }

    // MARK: - 외부 진입점

    func toggleChatBubble() {
        showPanel(.chat)
    }

    func showSessionHistory() {
        showPanel(.history)
    }

    func showPaletteMenu() {
        showPanel(.palette)
    }

    // MARK: - Position

    func applyPosition() {
        guard let panel = iconPanel,
              let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let margin: CGFloat = 15

        let origin: NSPoint
        switch AppSettings.shared.iconPosition {
        case .topLeft:
            origin = NSPoint(x: screenFrame.minX + margin,
                             y: screenFrame.maxY - panelSize.height - margin)
        case .bottomLeft:
            origin = NSPoint(x: screenFrame.minX + margin,
                             y: screenFrame.minY + margin)
        case .bottomRight:
            origin = NSPoint(x: screenFrame.maxX - panelSize.width - margin,
                             y: screenFrame.minY + margin)
        }
        panel.setFrameOrigin(origin)
    }

    // MARK: - Fullscreen Level

    func updatePanelLevel() {
        iconPanel?.level = AppSettings.shared.showOverFullscreen ? .screenSaver : .floating
    }

    // MARK: - Global Hotkey (Option+Space)

    private func registerHotKey() {
        hotKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            let isOption = event.modifierFlags.contains(.option)
            let isSpace  = event.keyCode == 49
            if isOption && isSpace {
                Task { @MainActor in self.toggleChatBubble() }
            }
        }
    }

    func removeHotKey() {
        if let monitor = hotKeyMonitor {
            NSEvent.removeMonitor(monitor)
            hotKeyMonitor = nil
        }
    }

    // MARK: - Misc

    var iconPanelFrame: NSRect { iconPanel?.frame ?? .zero }
}
