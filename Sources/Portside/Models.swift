import Foundation

struct DBEnvironment: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var colorHex: String
    var confirmBeforeConnect: Bool = false
}

struct DatabaseType: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var defaultPort: Int
}

struct ProxyInstance: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var environmentID: UUID
    var databaseTypeID: UUID
    var connectionName: String = ""
    var port: Int
    var autoStart: Bool = false
}

struct AppConfig: Codable {
    var environments: [DBEnvironment]
    var databaseTypes: [DatabaseType]
    var instances: [ProxyInstance]
    var gcloudPath: String = ""
    var proxyPath: String = ""

    static var initial: AppConfig {
        AppConfig(
            environments: [
                DBEnvironment(name: "Staging", colorHex: "#30B0C7"),
                DBEnvironment(name: "Release", colorHex: "#E08600"),
                DBEnvironment(name: "Production", colorHex: "#A3180E", confirmBeforeConnect: true),
            ],
            databaseTypes: [
                DatabaseType(name: "PostgreSQL", defaultPort: 5432),
                DatabaseType(name: "SQL Server", defaultPort: 1433),
            ],
            instances: []
        )
    }
}

enum ProxyStatus: Equatable {
    case stopped
    case starting
    case running
    case paused
    case failed(String)

    /// 開關是否應該顯示為「開」
    var isOn: Bool {
        switch self {
        case .starting, .running, .paused: return true
        case .stopped, .failed: return false
        }
    }
}

enum AuthState: Equatable {
    case unknown
    case checking
    case valid
    case expired
    case loggingIn
    case toolMissing
}
