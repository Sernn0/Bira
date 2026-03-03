import AppKit
import SwiftUI

// MARK: - PaletteMenuCoordinator

/// 팔레트 메뉴 NSPanel 표시 코디네이터
/// 롱프레스 시 아이콘 근처에 팝업으로 표시
@MainActor
final class PaletteMenuCoordinator {
    static let shared = PaletteMenuCoordinator()

    private var panel: NSPanel?
    private(set) var isVisible = false

    private init() {}

    func show(relativeTo iconPanel: NSPanel) {
        if panel == nil {
            createPanel()
        }

        positionPanel(relativeTo: iconPanel)
        panel?.orderFront(nil)
        isVisible = true
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    // MARK: - Panel Creation

    private func createPanel() {
        let menuPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 280),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        menuPanel.isFloatingPanel = true
        menuPanel.level = .floating
        menuPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        menuPanel.isOpaque = false
        menuPanel.backgroundColor = .clear
        menuPanel.hasShadow = true
        menuPanel.isMovable = false

        // 패널 외부 클릭 시 닫기 — 비활성 패널이라 별도 처리
        let contentView = PaletteMenuView(onDismiss: { [weak self] in
            self?.hide()
        })
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 200, height: 280)
        menuPanel.contentView = hostingView

        self.panel = menuPanel
    }

    // MARK: - Positioning

    private func positionPanel(relativeTo iconPanel: NSPanel) {
        guard let panel = panel else { return }

        let iconFrame = iconPanel.frame
        let gap: CGFloat = 8
        let panelSize = panel.frame.size

        // 아이콘 오른쪽 상단에 배치
        var origin = NSPoint(
            x: iconFrame.maxX + gap,
            y: iconFrame.minY + iconFrame.height / 2 - panelSize.height / 2
        )

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            if origin.x + panelSize.width > screenFrame.maxX {
                origin.x = iconFrame.minX - panelSize.width - gap
            }
            origin.y = max(screenFrame.minY, min(origin.y, screenFrame.maxY - panelSize.height))
        }

        panel.setFrameOrigin(origin)
    }
}

// MARK: - PaletteMenuView

struct PaletteMenuView: View {
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 2) {
            // 메뉴 아이템들
            PaletteMenuItem(
                icon: "gear",
                label: "설정",
                action: {
                    onDismiss?()
                    // TODO: 설정 패널 열기
                }
            )

            PaletteMenuItem(
                icon: "person.crop.circle",
                label: "캐릭터 설정",
                action: {
                    onDismiss?()
                    // TODO: 캐릭터 설정 열기
                }
            )

            PaletteMenuItem(
                icon: "puzzlepiece",
                label: "플러그인",
                action: {
                    onDismiss?()
                    // TODO: 플러그인 목록 열기
                }
            )

            Divider()
                .background(.white.opacity(0.1))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)

            // 위치 변경
            VStack(alignment: .leading, spacing: 2) {
                Text("아이콘 위치")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)

                ForEach(IconPosition.allCases, id: \.self) { position in
                    PositionMenuItem(
                        position: position,
                        isSelected: AppSettings.shared.iconPosition == position,
                        action: {
                            AppSettings.shared.iconPosition = position
                            OverlayWindowManager.shared.applyPosition()
                            onDismiss?()
                        }
                    )
                }
            }

            Divider()
                .background(.white.opacity(0.1))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)

            PaletteMenuItem(
                icon: "xmark.circle",
                label: "종료",
                isDestructive: true,
                action: {
                    onDismiss?()
                    NSApplication.shared.terminate(nil)
                }
            )
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }
}

// MARK: - Subviews

private struct PaletteMenuItem: View {
    let icon: String
    let label: String
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 18, height: 18)
                    .foregroundStyle(isDestructive ? .red : .primary)

                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(isDestructive ? .red : .primary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? Color.white.opacity(0.06) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .onHover { isHovered = $0 }
    }
}

private struct PositionMenuItem: View {
    let position: IconPosition
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: position.iconName)
                    .font(.system(size: 12))
                    .frame(width: 18, height: 18)
                    .foregroundStyle(isSelected ? Color(hex: "#A78BFA") : .secondary)

                Text(position.displayName)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "#A78BFA"))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovered ? Color.white.opacity(0.06) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .onHover { isHovered = $0 }
    }
}

// MARK: - IconPosition Extension

private extension IconPosition {
    var iconName: String {
        switch self {
        case .topLeft:     return "arrow.up.left"
        case .bottomLeft:  return "arrow.down.left"
        case .bottomRight: return "arrow.down.right"
        }
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
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview {
    PaletteMenuView()
        .frame(width: 200, height: 280)
}
