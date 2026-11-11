import Foundation

@MainActor
final class ProxyManager: ObservableObject {
    static let shared = ProxyManager()

    @Published private(set) var statuses: [UUID: ProxyStatus] = [:]

    private var processes: [UUID: Process] = [:]
    private var intentionalStops: Set<UUID> = []
    private var lastLines: [UUID: String] = [:]

    private init() {}

    func status(of id: UUID) -> ProxyStatus {
        statuses[id] ?? .stopped
    }

    var runningCount: Int {
        statuses.values.filter { $0 == .running || $0 == .starting }.count
    }

    // MARK: - 啟動與停止

    func start(_ instance: ProxyInstance) {
        let id = instance.id
        guard processes[id] == nil else { return }

        guard let proxyPath = ToolLocator.proxyPath() else {
            statuses[id] = .failed("找不到 cloud-sql-proxy，請到設定指定路徑")
            return
        }
        let connection = instance.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !connection.isEmpty else {
            statuses[id] = .failed("尚未填寫 Instance 連線名稱")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: proxyPath)
        process.arguments = ["\(connection)?port=\(instance.port)"]
        process.environment = Shell.environment
        process.standardInput = FileHandle.nullDevice

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            let text = String(decoding: data, as: UTF8.self)
            Task { @MainActor in ProxyManager.shared.handleOutput(text, for: id) }
        }
        process.terminationHandler = { finished in
            let code = finished.terminationStatus
            Task { @MainActor in ProxyManager.shared.handleExit(code, for: id, process: finished) }
        }

        do {
            try process.run()
            processes[id] = process
            lastLines[id] = nil
            statuses[id] = .starting
        } catch {
            statuses[id] = .failed(error.localizedDescription)
        }
    }

    func stop(_ id: UUID) {
        guard let process = processes[id] else {
            statuses[id] = .stopped
            return
        }
        statuses[id] = .stopped
        intentionalStops.insert(id)
        process.terminate()
    }

    func stopAll() {
        for id in Array(statuses.keys) { stop(id) }
    }

    /// app 結束前呼叫：直接終止所有子進程，不等回呼
    func terminateAllNow() {
        for process in processes.values where process.isRunning {
            process.terminate()
        }
    }

    // MARK: - 驗證過期

    func pauseAllForAuth() {
        for (id, status) in statuses where status == .running || status == .starting {
            statuses[id] = .paused
            if let process = processes[id] {
                intentionalStops.insert(id)
                process.terminate()
            }
        }
    }

    /// 驗證失效期間使用者打開開關：先排隊，登入成功後再啟動
    func queueUntilAuthenticated(_ id: UUID) {
        statuses[id] = .paused
    }

    func resumePaused() {
        for instance in ConfigStore.shared.config.instances where status(of: instance.id) == .paused {
            if processes[instance.id] == nil {
                start(instance)
            } else {
                // 舊進程還沒完全結束，稍後再試一次
                let pending = instance
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if ProxyManager.shared.status(of: pending.id) == .paused {
                        ProxyManager.shared.start(pending)
                    }
                }
            }
        }
    }

    // MARK: - 子進程回呼

    private func handleOutput(_ text: String, for id: UUID) {
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            let lower = line.lowercased()

            if lower.contains("address already in use") {
                lastLines[id] = "Port 已被其他程式佔用"
            } else {
                lastLines[id] = line
            }

            if lower.contains("ready for new connections"), statuses[id] == .starting {
                statuses[id] = .running
            }
            if looksLikeAuthFailure(line) {
                AuthManager.shared.markExpired()
                pauseAllForAuth()
            }
        }
    }

    private func handleExit(_ code: Int32, for id: UUID, process: Process) {
        guard processes[id] === process else { return }
        processes[id] = nil

        if intentionalStops.remove(id) != nil {
            // 使用者關掉或因驗證暫停：狀態已經設定好，不要覆蓋
            return
        }
        statuses[id] = .failed(lastLines[id] ?? "已結束（代碼 \(code)）")
    }
}
