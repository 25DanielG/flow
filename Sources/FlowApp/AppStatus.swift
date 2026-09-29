import Foundation

@MainActor
final class AppStatus: ObservableObject {
    enum State {
        case idle
        case recording
        case locked
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastRouting: String?
    @Published private(set) var notice: String?
    var onToast: ((String) -> Void)?

    private var noticeGeneration = 0

    func setDictationState(_ state: State) {
        self.state = state
    }

    func setLastRouting(_ text: String) {
        lastRouting = text
    }

    func flashError(_ message: String) {
        notice = message
        onToast?(message)
        noticeGeneration += 1
        let generation = noticeGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, self.noticeGeneration == generation else { return }
            self.notice = nil
        }
    }
}
