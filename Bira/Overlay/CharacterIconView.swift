import AppKit
import SwiftUI

// MARK: - IconHostingView
// NSHostingView를 서브클래싱해 마우스 이벤트를 직접 처리한다.
// nonactivatingPanel 위에서도 클릭/더블클릭/롱프레스가 안정적으로 동작한다.

final class IconHostingView: NSHostingView<CharacterIconView> {

    private var longPressTimer: Timer?
    private var longPressTriggered = false
    private var clickCount = 0
    private var clickTimer: Timer?

    // MARK: - 커서를 화살표로 고정 (로딩 커서 방지)
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    // MARK: - 호버

    override func mouseEntered(with event: NSEvent) {
        rootView.isHovered = true
        window?.invalidateCursorRects(for: self)
    }

    override func mouseExited(with event: NSEvent) {
        rootView.isHovered = false
    }

    // MARK: - 마우스 다운/업

    override func mouseDown(with event: NSEvent) {
        longPressTriggered = false
        rootView.isPressed = true

        // 팔레트가 이미 열려 있으면 롱프레스 타이머 불필요 (mouseUp에서 닫기)
        guard OverlayWindowManager.shared.currentPanel != .palette else { return }

        // 롱프레스 타이머 시작 (0.5초)
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.longPressTriggered = true
                self.rootView.isPressed = false
                OverlayWindowManager.shared.showPaletteMenu()
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        longPressTimer?.invalidate()
        longPressTimer = nil
        rootView.isPressed = false

        guard !longPressTriggered else {
            longPressTriggered = false
            return
        }

        // 팔레트가 열려 있는 상태에서 짧게 눌렀다 뗀 경우 → 닫기
        if OverlayWindowManager.shared.currentPanel == .palette {
            OverlayWindowManager.shared.closeCurrentPanel()
            return
        }

        // 더블클릭 vs 단순 클릭 판별
        clickCount += 1
        if event.clickCount == 2 || clickCount == 2 {
            clickTimer?.invalidate()
            clickTimer = nil
            clickCount = 0
            Task { @MainActor in
                OverlayWindowManager.shared.showSessionHistory()
            }
        } else {
            // 단일 클릭: 더블클릭 판별 대기 (0.25초)
            clickTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    if self.clickCount == 1 {
                        OverlayWindowManager.shared.toggleChatBubble()
                    }
                    self.clickCount = 0
                }
            }
        }
    }
}

// MARK: - CharacterIconView (렌더링 전용)

struct CharacterIconView: View {
    var isHovered: Bool = false
    var isPressed: Bool = false

    var body: some View {
        ZStack {
            // 호버 글로우
            if isHovered {
                Circle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 58, height: 58)
            }

            // 캐릭터 이미지 — 원형 클리핑
            Group {
                if let image = NSImage(named: "character") {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                } else {
                    PlaceholderIconView()
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(isHovered ? 0.4 : 0.15), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            .scaleEffect(isPressed ? 0.88 : (isHovered ? 1.04 : 1.0))
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: isPressed)
            .animation(.easeInOut(duration: 0.12), value: isHovered)
        }
        .frame(width: 60, height: 60)
    }
}

// MARK: - Placeholder

private struct PlaceholderIconView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color(hex: "#A78BFA"), Color(hex: "#7C3AED")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Text("B")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .shadow(color: Color(hex: "#7C3AED").opacity(0.5), radius: 6, y: 3)
    }
}

// MARK: - Color Hex Helper

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Preview

#Preview {
    CharacterIconView(isHovered: false)
        .frame(width: 60, height: 60)
        .background(Color.black.opacity(0.4))
}
