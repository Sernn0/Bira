import Foundation
import Observation

enum IconPosition: String, CaseIterable {
    case topLeft = "topLeft"
    case bottomLeft = "bottomLeft"
    case bottomRight = "bottomRight"

    var displayName: String {
        switch self {
        case .topLeft: return "좌상단"
        case .bottomLeft: return "좌하단"
        case .bottomRight: return "우하단"
        }
    }
}

enum AIModel: String, CaseIterable {
    case claudeSonnet = "claude-sonnet"
    case claudeOpus = "claude-opus"
    case gemini = "gemini"

    var displayName: String {
        switch self {
        case .claudeSonnet: return "Claude Sonnet"
        case .claudeOpus: return "Claude Opus"
        case .gemini: return "Gemini"
        }
    }
}

private let kUserName = "bira.userName"
private let kPersonality = "bira.characterPersonality"
private let kSelectedModel = "bira.selectedModel"
private let kIconPosition = "bira.iconPosition"
private let kGatewayPort = "bira.gatewayPort"
private let kOnboardingSeen = "bira.onboardingSeen"
private let kShowOverFullscreen = "bira.showOverFullscreen"
private let kKeepOpenAfterOutput = "bira.keepOpenAfterOutput"

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    var userName: String {
        didSet { UserDefaults.standard.set(userName, forKey: kUserName) }
    }

    var characterPersonality: String {
        didSet { UserDefaults.standard.set(characterPersonality, forKey: kPersonality) }
    }

    var selectedModel: AIModel {
        didSet { UserDefaults.standard.set(selectedModel.rawValue, forKey: kSelectedModel) }
    }

    var iconPosition: IconPosition {
        didSet { UserDefaults.standard.set(iconPosition.rawValue, forKey: kIconPosition) }
    }

    var gatewayPort: Int {
        didSet { UserDefaults.standard.set(gatewayPort, forKey: kGatewayPort) }
    }

    var onboardingSeen: Bool {
        didSet { UserDefaults.standard.set(onboardingSeen, forKey: kOnboardingSeen) }
    }

    /// 전체화면에서도 오버레이 표시
    var showOverFullscreen: Bool {
        didSet { UserDefaults.standard.set(showOverFullscreen, forKey: kShowOverFullscreen) }
    }

    /// 결과 출력 후 다른 앱 포커스 시 말풍선 유지 여부 (기본: 닫기)
    var keepOpenAfterOutput: Bool {
        didSet { UserDefaults.standard.set(keepOpenAfterOutput, forKey: kKeepOpenAfterOutput) }
    }

    private init() {
        let defaults = UserDefaults.standard
        self.userName = defaults.string(forKey: kUserName) ?? ""
        self.characterPersonality = defaults.string(forKey: kPersonality) ?? ""
        let modelRaw = defaults.string(forKey: kSelectedModel) ?? ""
        self.selectedModel = AIModel(rawValue: modelRaw) ?? .claudeSonnet
        let posRaw = defaults.string(forKey: kIconPosition) ?? ""
        self.iconPosition = IconPosition(rawValue: posRaw) ?? .topLeft
        let port = defaults.integer(forKey: kGatewayPort)
        self.gatewayPort = port > 0 ? port : 18789
        self.onboardingSeen = defaults.bool(forKey: kOnboardingSeen)
        self.showOverFullscreen = defaults.bool(forKey: kShowOverFullscreen)
        self.keepOpenAfterOutput = defaults.bool(forKey: kKeepOpenAfterOutput)
    }
}
