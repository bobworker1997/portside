import Foundation

enum Shell {
    /// 從 Finder 啟動的 app 不會繼承 shell 的 PATH，這裡補上常見位置（gcloud 需要找得到 python3）
    static let environment: [String: String] = {
        var env = ProcessInfo.processInfo.environment
        let extra = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        if let path = env["PATH"], !path.isEmpty {
            env["PATH"] = extra + ":" + path
        } else {
            env["PATH"] = extra
        }
        return env
    }()

    /// 執行指令並等它結束。只回傳結束代碼與 stderr，stdout 直接丟棄（避免把 access token 留在記憶體裡）。
    static func run(_ path: String, _ arguments: [String]) async -> (status: Int32, stderr: String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = arguments
                process.environment = environment
                process.standardInput = FileHandle.nullDevice
                process.standardOutput = FileHandle.nullDevice
                let errPipe = Pipe()
                process.standardError = errPipe
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: (-1, error.localizedDescription))
                    return
                }
                let data = errPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: (process.terminationStatus, String(decoding: data, as: UTF8.self)))
            }
        }
    }
}

enum ToolLocator {
    static func find(_ name: String) -> String? {
        let home = NSHomeDirectory()
        let directories = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/opt/homebrew/share/google-cloud-sdk/bin",
            "/usr/local/share/google-cloud-sdk/bin",
            "\(home)/google-cloud-sdk/bin",
            "\(home)/bin",
            "\(home)/.local/bin",
        ]
        for directory in directories {
            let path = directory + "/" + name
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }

    private static func resolve(custom: String, name: String) -> String? {
        let trimmed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return find(name) }
        let expanded = (trimmed as NSString).expandingTildeInPath
        return FileManager.default.isExecutableFile(atPath: expanded) ? expanded : nil
    }

    @MainActor static func gcloudPath() -> String? {
        resolve(custom: ConfigStore.shared.config.gcloudPath, name: "gcloud")
    }

    @MainActor static func proxyPath() -> String? {
        resolve(custom: ConfigStore.shared.config.proxyPath, name: "cloud-sql-proxy")
    }
}

/// 判斷錯誤訊息是否代表 Google 驗證失效
func looksLikeAuthFailure(_ text: String) -> Bool {
    let lower = text.lowercased()
    let patterns = [
        "invalid_grant",
        "invalid_rapt",
        "reauth",
        "application-default login",
        "could not find default credentials",
        "could not automatically determine credentials",
    ]
    return patterns.contains { lower.contains($0) }
}
