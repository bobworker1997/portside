import Foundation

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var state: AuthState = .unknown
    @Published private(set) var lastChecked: Date?

    private var loginProcess: Process?
    private var timer: Timer?

    private init() {}

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor in await AuthManager.shared.check() }
        }
    }

    /// 用 print-access-token 實際換一次 token，確認 ADC 還有效
    func check() async {
        guard state != .loggingIn else { return }
        guard let gcloud = ToolLocator.gcloudPath() else {
            state = .toolMissing
            return
        }
        if state == .unknown || state == .toolMissing { state = .checking }

        let result = await Shell.run(gcloud, ["auth", "application-default", "print-access-token"])
        guard state != .loggingIn else { return }
        lastChecked = Date()

        if result.status == 0 {
            let wasExpired = state == .expired
            state = .valid
            if wasExpired { ProxyManager.shared.resumePaused() }
        } else if looksLikeAuthFailure(result.stderr) {
            markExpired()
        } else if state == .checking {
            // 其他錯誤（例如沒有網路）不當成過期
            state = .unknown
        }
    }

    func markExpired() {
        guard state != .expired, state != .loggingIn else { return }
        state = .expired
        ProxyManager.shared.pauseAllForAuth()
    }

    /// 執行 gcloud auth application-default login，它會自己開瀏覽器
    func login() {
        guard loginProcess == nil else { return }
        guard let gcloud = ToolLocator.gcloudPath() else {
            state = .toolMissing
            return
        }
        ProxyManager.shared.pauseAllForAuth()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: gcloud)
        process.arguments = ["auth", "application-default", "login"]
        process.environment = Shell.environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { finished in
            let code = finished.terminationStatus
            Task { @MainActor in AuthManager.shared.loginFinished(code) }
        }
        do {
            try process.run()
            loginProcess = process
            state = .loggingIn
        } catch {
            state = .expired
        }
    }

    func cancelLogin() {
        loginProcess?.terminate()
    }

    private func loginFinished(_ code: Int32) {
        loginProcess = nil
        if code == 0 {
            state = .valid
            lastChecked = Date()
            ProxyManager.shared.resumePaused()
        } else {
            state = .expired
        }
    }
}
