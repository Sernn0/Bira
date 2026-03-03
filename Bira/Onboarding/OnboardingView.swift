import SwiftUI
import AppKit

// MARK: - OnboardingWindowManager

/// 온보딩 창 관리 (최초 실행 시 표시)
@MainActor
final class OnboardingWindowManager {
    static let shared = OnboardingWindowManager()

    private var window: NSWindow?

    private init() {}

    func show() {
        if window == nil {
            createWindow()
        }
        window?.center()
        window?.orderFrontRegardless()
    }

    func dismiss() {
        window?.close()
        window = nil
        // 온보딩 완료 후 오버레이 시작
        OverlayWindowManager.shared.setup()
    }

    private func createWindow() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.backgroundColor = .clear
        win.isOpaque = false
        win.center()

        let onboardingView = OnboardingView {
            OnboardingWindowManager.shared.dismiss()
        }
        win.contentView = NSHostingView(rootView: onboardingView)
        self.window = win
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    var onComplete: (() -> Void)?

    @State private var currentStep = 0
    @State private var userName = AppSettings.shared.userName
    @State private var personality = AppSettings.shared.characterPersonality
    @State private var selectedModel = AppSettings.shared.selectedModel
    @State private var selectedPosition = AppSettings.shared.iconPosition
    @State private var gatewayPort = String(AppSettings.shared.gatewayPort)

    private let totalSteps = 5

    var body: some View {
        ZStack {
            // 배경
            LinearGradient(
                colors: [Color(hex: "#1a0533"), Color(hex: "#0d1240")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 진행 표시기
                StepIndicatorView(currentStep: currentStep, totalSteps: totalSteps)
                    .padding(.top, 24)
                    .padding(.horizontal, 40)

                // 단계별 콘텐츠
                TabView(selection: $currentStep) {
                    Step1NameView(userName: $userName).tag(0)
                    Step2PersonalityView(personality: $personality).tag(1)
                    Step3ModelView(selectedModel: $selectedModel).tag(2)
                    Step4PositionView(selectedPosition: $selectedPosition).tag(3)
                    Step5GatewayView(gatewayPort: $gatewayPort).tag(4)
                }
                .tabViewStyle(.automatic)
                .animation(.easeInOut(duration: 0.3), value: currentStep)

                // 하단 버튼
                HStack(spacing: 12) {
                    if currentStep > 0 {
                        Button("이전") {
                            withAnimation { currentStep -= 1 }
                        }
                        .buttonStyle(OnboardingSecondaryButtonStyle())
                    }

                    Button(currentStep == totalSteps - 1 ? "시작하기" : "다음") {
                        if currentStep == totalSteps - 1 {
                            saveAndComplete()
                        } else {
                            withAnimation { currentStep += 1 }
                        }
                    }
                    .buttonStyle(OnboardingPrimaryButtonStyle())
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
                .padding(.top, 16)
            }
        }
        .frame(width: 480, height: 560)
    }

    private func saveAndComplete() {
        AppSettings.shared.userName = userName
        AppSettings.shared.characterPersonality = personality
        AppSettings.shared.selectedModel = selectedModel
        AppSettings.shared.iconPosition = selectedPosition
        AppSettings.shared.gatewayPort = Int(gatewayPort) ?? 18789
        AppSettings.shared.onboardingSeen = true
        onComplete?()
    }
}

// MARK: - Step Views

private struct Step1NameView: View {
    @Binding var userName: String

    var body: some View {
        OnboardingStepContainer(
            emoji: "👋",
            title: "Bira가 당신을\n어떻게 부를까요?",
            subtitle: "편하게 불러줄 이름을 알려주세요"
        ) {
            TextField("닉네임 또는 이름", text: $userName)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

private struct Step2PersonalityView: View {
    @Binding var personality: String

    var body: some View {
        OnboardingStepContainer(
            emoji: "✨",
            title: "Bira의 성격과\n말투는 어때야 할까요?",
            subtitle: "자유롭게 적어주세요. 예: \"친구처럼 편하게, 가끔 장난도 치는 스타일\""
        ) {
            ZStack(alignment: .topLeading) {
                if personality.isEmpty {
                    Text("예: 유쾌하고 직접적이며, 존댓말 없이 반말로 편하게 대화하는 스타일")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $personality)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(height: 100)
            }
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

private struct Step3ModelView: View {
    @Binding var selectedModel: AIModel

    var body: some View {
        OnboardingStepContainer(
            emoji: "🧠",
            title: "어떤 AI 모델로\n작동할까요?",
            subtitle: "선택한 모델에 맞는 계정 연결이 필요해요"
        ) {
            VStack(spacing: 8) {
                ForEach(AIModel.allCases, id: \.self) { model in
                    ModelOptionRow(
                        model: model,
                        isSelected: selectedModel == model,
                        action: { selectedModel = model }
                    )
                }
            }
        }
    }
}

private struct ModelOptionRow: View {
    let model: AIModel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .strokeBorder(isSelected ? Color(hex: "#A78BFA") : .white.opacity(0.3), lineWidth: 2)
                    .overlay(
                        Circle()
                            .fill(isSelected ? Color(hex: "#A78BFA") : .clear)
                            .padding(4)
                    )
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                    Text(model.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color(hex: "#A78BFA").opacity(0.15) : Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color(hex: "#A78BFA").opacity(0.5) : .white.opacity(0.1),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct Step4PositionView: View {
    @Binding var selectedPosition: IconPosition

    var body: some View {
        OnboardingStepContainer(
            emoji: "📌",
            title: "Bira를 화면의\n어디에 배치할까요?",
            subtitle: "나중에 팔레트 메뉴에서 변경할 수 있어요"
        ) {
            // 화면 미리보기 with 위치 선택
            PositionPickerView(selectedPosition: $selectedPosition)
        }
    }
}

private struct PositionPickerView: View {
    @Binding var selectedPosition: IconPosition

    var body: some View {
        ZStack {
            // 화면 프레임
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                )
                .frame(height: 140)

            // 위치 버튼들
            VStack {
                HStack {
                    PositionDot(position: .topLeft, selected: $selectedPosition)
                    Spacer()
                }
                Spacer()
                HStack {
                    PositionDot(position: .bottomLeft, selected: $selectedPosition)
                    Spacer()
                    PositionDot(position: .bottomRight, selected: $selectedPosition)
                }
            }
            .padding(16)
        }
        .frame(height: 140)
    }
}

private struct PositionDot: View {
    let position: IconPosition
    @Binding var selected: IconPosition

    var isSelected: Bool { selected == position }

    var body: some View {
        Button {
            selected = position
        } label: {
            ZStack {
                Circle()
                    .fill(isSelected ? Color(hex: "#A78BFA") : Color.white.opacity(0.2))
                    .frame(width: 28, height: 28)

                if isSelected {
                    Text("B")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.2), value: isSelected)
    }
}

private struct Step5GatewayView: View {
    @Binding var gatewayPort: String

    var body: some View {
        OnboardingStepContainer(
            emoji: "🔌",
            title: "Gateway 포트를\n설정해요",
            subtitle: "OpenClaw Gateway가 사용할 로컬 포트예요.\n기본값(18789)을 그대로 사용해도 됩니다."
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    TextField("18789", text: $gatewayPort)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                        )
                        .frame(width: 120)
                        .onChange(of: gatewayPort) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue { gatewayPort = filtered }
                        }

                    Button("기본값으로") {
                        gatewayPort = "18789"
                    }
                    .buttonStyle(OnboardingSecondaryButtonStyle())
                }

                Text("앱 실행 시 localhost:\(gatewayPort.isEmpty ? "18789" : gatewayPort)에 자동 연결됩니다")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}

// MARK: - Container

private struct OnboardingStepContainer<Content: View>: View {
    let emoji: String
    let title: String
    let subtitle: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(emoji)
                    .font(.system(size: 40))

                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(4)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineSpacing(3)
            }

            content()

            Spacer()
        }
        .padding(.horizontal, 40)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Step Indicator

private struct StepIndicatorView: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i == currentStep ? Color(hex: "#A78BFA") : Color.white.opacity(0.2))
                    .frame(width: i == currentStep ? 24 : 8, height: 6)
                    .animation(.spring(response: 0.3), value: currentStep)
            }
            Spacer()
        }
    }
}

// MARK: - Button Styles

struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#A78BFA"), Color(hex: "#7C3AED")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct OnboardingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - AIModel Extension

private extension AIModel {
    var description: String {
        switch self {
        case .claudeSonnet: return "균형 잡힌 성능과 속도 (추천)"
        case .claudeOpus:   return "최고 성능, 복잡한 작업에 적합"
        case .gemini:       return "Google Gemini, 빠른 응답"
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

#Preview("Onboarding") {
    OnboardingView()
        .frame(width: 480, height: 560)
}
