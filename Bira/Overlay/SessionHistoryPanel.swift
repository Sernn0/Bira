import AppKit
import SwiftUI

/// 최근 대화 목록 NSPanel 관리자
/// 더블클릭 시 아이콘 아래에 표시
@MainActor
final class SessionHistoryPanel {
    static let shared = SessionHistoryPanel()

    private var panel: NSPanel?
    private(set) var isVisible = false

    private init() {}

    // MARK: - Show / Hide

    func show(relativeTo iconPanel: NSPanel?) {
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

    func toggle(relativeTo iconPanel: NSPanel?) {
        isVisible ? hide() : show(relativeTo: iconPanel)
    }

    // MARK: - Panel Creation

    private func createPanel() {
        let historyPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 320),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        historyPanel.isFloatingPanel = true
        historyPanel.level = .floating
        historyPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        historyPanel.isOpaque = false
        historyPanel.backgroundColor = .clear
        historyPanel.hasShadow = true
        historyPanel.isMovable = false

        let contentView = SessionHistoryView(onDismiss: { [weak self] in
            self?.hide()
        })
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 260, height: 320)
        historyPanel.contentView = hostingView

        self.panel = historyPanel
    }

    // MARK: - Positioning

    /// 아이콘 아래에 8px 여백으로 배치
    private func positionPanel(relativeTo iconPanel: NSPanel?) {
        guard let panel = panel else { return }

        let iconFrame: NSRect
        if let iconPanel = iconPanel {
            iconFrame = iconPanel.frame
        } else {
            let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            iconFrame = NSRect(x: 15, y: screen.maxY - 75, width: 60, height: 60)
        }

        let gap: CGFloat = 8
        let panelSize = panel.frame.size

        var origin = NSPoint(
            x: iconFrame.minX,
            y: iconFrame.minY - panelSize.height - gap
        )

        // 화면 밖으로 나가지 않도록 보정
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            if origin.y < screenFrame.minY {
                // 아래 공간이 없으면 위에 배치
                origin.y = iconFrame.maxY + gap
            }
            origin.x = max(screenFrame.minX, min(origin.x, screenFrame.maxX - panelSize.width))
        }

        panel.setFrameOrigin(origin)
    }
}

// MARK: - SessionHistoryView

struct SessionHistoryView: View {
    var onDismiss: (() -> Void)?

    // TODO: 실제 Gateway 연결 후 ChatSessionManager에서 이력 로드
    @State private var sessions: [HistorySession] = HistorySession.placeholders

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("최근 대화")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    onDismiss?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()
                .background(.white.opacity(0.1))

            if sessions.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("대화 기록이 없어요")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(sessions) { session in
                            SessionRow(session: session)
                                .onTapGesture {
                                    // TODO: 해당 세션으로 이동
                                    onDismiss?()
                                }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }
}

private struct SessionRow: View {
    let session: HistorySession
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: "#A78BFA").opacity(0.4))
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.preview)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(session.relativeTime)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(isHovered ? Color.white.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { isHovered = $0 }
    }
}

// MARK: - Placeholder Model

struct HistorySession: Identifiable {
    let id = UUID()
    let preview: String
    let date: Date

    var relativeTime: String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return "\(Int(interval / 60))분 전" }
        if interval < 86400 { return "\(Int(interval / 3600))시간 전" }
        return "\(Int(interval / 86400))일 전"
    }

    static let placeholders: [HistorySession] = []
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
    SessionHistoryView()
        .frame(width: 260, height: 320)
}
