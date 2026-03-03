import SwiftUI

/// 말풍선 내부 SwiftUI 뷰
/// - 상단: AI 응답 출력 영역
/// - 하단: 텍스트 입력창 + 전송 버튼
struct ChatBubbleView: View {
    var onActivity: (() -> Void)?

    @State private var inputText = ""
    @State private var messages: [BubbleMessage] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            BubbleHeaderView()

            Divider()
                .background(.white.opacity(0.1))

            // 메시지 목록
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(messages) { message in
                            BubbleMessageRow(message: message)
                                .id(message.id)
                        }

                        if isLoading {
                            TypingIndicatorView()
                                .id("loading")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id) }
                    }
                    onActivity?()
                }
                .onChange(of: isLoading) { _, loading in
                    if loading {
                        withAnimation { proxy.scrollTo("loading") }
                    }
                }
            }

            Divider()
                .background(.white.opacity(0.1))

            // 입력창
            BubbleInputView(
                text: $inputText,
                onSend: sendMessage,
                onActivity: onActivity
            )
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        let userMsg = BubbleMessage(role: .user, content: text)
        messages.append(userMsg)
        isLoading = true

        ChatSessionManager.shared.touch()
        onActivity?()

        // TODO: Gateway WebSocket 연결 후 실제 전송 구현
        // 현재는 플레이스홀더 응답
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                isLoading = false
                let reply = BubbleMessage(
                    role: .assistant,
                    content: "안녕! 아직 Gateway 연결 전이라 실제 응답은 못 하지만, 곧 연결할게. 😊"
                )
                messages.append(reply)
                onActivity?()
            }
        }
    }
}

// MARK: - Subviews

private struct BubbleHeaderView: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: "#A78BFA"))
                .frame(width: 8, height: 8)

            Text("Bira")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                ChatBubblePanel.shared.hide()
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
    }
}

private struct BubbleMessageRow: View {
    let message: BubbleMessage

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            if message.role == .assistant {
                Circle()
                    .fill(Color(hex: "#A78BFA"))
                    .frame(width: 6, height: 6)
                    .padding(.top, 6)
            }

            Text(message.content)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(message.role == .user
                              ? Color(hex: "#7C3AED").opacity(0.25)
                              : Color.white.opacity(0.06))
                )

            if message.role == .user {
                Circle()
                    .fill(.secondary.opacity(0.4))
                    .frame(width: 6, height: 6)
                    .padding(.top, 6)
            }
        }
    }
}

private struct TypingIndicatorView: View {
    @State private var dotOpacities: [Double] = [0.3, 0.3, 0.3]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(hex: "#A78BFA"))
                    .frame(width: 6, height: 6)
                    .opacity(dotOpacities[i])
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
        .onAppear { animateDots() }
    }

    private func animateDots() {
        for i in 0..<3 {
            withAnimation(
                .easeInOut(duration: 0.4)
                .repeatForever()
                .delay(Double(i) * 0.15)
            ) {
                dotOpacities[i] = 1.0
            }
        }
    }
}

private struct BubbleInputView: View {
    @Binding var text: String
    var onSend: () -> Void
    var onActivity: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            TextField("Bira에게 말하기...", text: $text, axis: .vertical)
                .font(.system(size: 13))
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.08))
                )
                .onChange(of: text) { _, _ in
                    onActivity?()
                }
                .onSubmit {
                    if !text.isEmpty {
                        onSend()
                    }
                }

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                     ? AnyShapeStyle(Color.secondary.opacity(0.4))
                                     : AnyShapeStyle(Color(hex: "#A78BFA")))
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Model

struct BubbleMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp = Date()
}

enum MessageRole {
    case user
    case assistant
}

// MARK: - Color Hex Helper (local scope)

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
    ChatBubbleView()
        .frame(width: 320, height: 400)
}
