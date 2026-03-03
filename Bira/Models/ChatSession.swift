import Foundation
import Observation

private let sessionTimeoutSeconds: TimeInterval = 900 // 15분

@MainActor
@Observable
final class ChatSessionManager {
    static let shared = ChatSessionManager()

    private(set) var currentSessionKey: String = UUID().uuidString
    private var lastActivityDate: Date = Date()

    /// 새 메시지를 보내기 전 호출. 타임아웃이면 새 세션 생성.
    func sessionKeyForSend() -> String {
        if isExpired {
            startNewSession()
        }
        touch()
        return currentSessionKey
    }

    /// 활동 시각 갱신
    func touch() {
        lastActivityDate = Date()
    }

    /// 세션이 만료됐는지
    var isExpired: Bool {
        Date().timeIntervalSince(lastActivityDate) > sessionTimeoutSeconds
    }

    /// 강제로 새 세션 시작
    func startNewSession() {
        currentSessionKey = UUID().uuidString
        lastActivityDate = Date()
    }

    private init() {}
}
