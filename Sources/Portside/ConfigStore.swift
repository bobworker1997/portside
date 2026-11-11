import Foundation

@MainActor
final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()

    @Published var config: AppConfig {
        didSet { save() }
    }

    let fileURL: URL

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Portside", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("config.json")

        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode(AppConfig.self, from: data) {
            config = loaded
        } else {
            config = .initial
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func environment(_ id: UUID) -> DBEnvironment? {
        config.environments.first { $0.id == id }
    }

    func databaseType(_ id: UUID) -> DatabaseType? {
        config.databaseTypes.first { $0.id == id }
    }

    /// 從資料庫類型的預設 port 開始，找第一個還沒被其他連線使用的 port
    func nextFreePort(startingAt port: Int) -> Int {
        let used = Set(config.instances.map(\.port))
        var candidate = port
        while used.contains(candidate) { candidate += 1 }
        return candidate
    }
}
