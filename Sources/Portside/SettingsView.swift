import AppKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            InstancesTab()
                .tabItem { Label("連線", systemImage: "cable.connector") }
            EnvironmentsTab()
                .tabItem { Label("環境", systemImage: "square.stack.3d.up") }
            DatabaseTypesTab()
                .tabItem { Label("資料庫類型", systemImage: "cylinder.split.1x2") }
            GeneralTab()
                .tabItem { Label("一般", systemImage: "gearshape") }
        }
        .padding(12)
        .frame(width: 740, height: 500)
    }
}

// MARK: - 連線

/// 用 ObservableObject 保存選取狀態，避免使用 @State
/// （只裝 Command Line Tools 時，新版 SDK 的 @State macro 外掛不存在，會編譯失敗）
private final class SelectionModel: ObservableObject {
    @Published var selection: UUID?
}

private struct InstancesTab: View {
    @EnvironmentObject private var store: ConfigStore
    @EnvironmentObject private var proxy: ProxyManager
    @StateObject private var selectionModel = SelectionModel()

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $selectionModel.selection) {
                    ForEach(store.config.databaseTypes) { type in
                        let items = store.config.instances.filter { $0.databaseTypeID == type.id }
                        if !items.isEmpty {
                            Section(type.name) {
                                ForEach(items) { instance in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color(hex: store.environment(instance.environmentID)?.colorHex ?? "#8E8E93"))
                                            .frame(width: 8, height: 8)
                                        Text(instance.name)
                                    }
                                    .tag(instance.id)
                                }
                            }
                        }
                    }
                }
                Divider()
                HStack(spacing: 4) {
                    Button(action: add) { Image(systemName: "plus") }
                        .help("新增連線")
                        .disabled(store.config.environments.isEmpty || store.config.databaseTypes.isEmpty)
                    Button(action: removeSelected) { Image(systemName: "minus") }
                        .help("刪除連線")
                        .disabled(selectionModel.selection == nil)
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(8)
            }
            .frame(width: 220)

            Divider()

            if let id = selectionModel.selection, store.config.instances.contains(where: { $0.id == id }) {
                InstanceForm(instance: binding(for: id))
                    .id(id)
            } else {
                Text(store.config.instances.isEmpty ? "按左下角的 + 新增第一個連線" : "選擇一個連線來編輯")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func binding(for id: UUID) -> Binding<ProxyInstance> {
        Binding(
            get: {
                store.config.instances.first { $0.id == id }
                    ?? ProxyInstance(name: "", environmentID: UUID(), databaseTypeID: UUID(), port: 0)
            },
            set: { updated in
                if let index = store.config.instances.firstIndex(where: { $0.id == id }) {
                    store.config.instances[index] = updated
                }
            }
        )
    }

    private func add() {
        guard let environment = store.config.environments.first,
              let type = store.config.databaseTypes.first else { return }
        let instance = ProxyInstance(
            name: "新連線",
            environmentID: environment.id,
            databaseTypeID: type.id,
            port: store.nextFreePort(startingAt: type.defaultPort)
        )
        store.config.instances.append(instance)
        selectionModel.selection = instance.id
    }

    private func removeSelected() {
        guard let id = selectionModel.selection else { return }
        selectionModel.selection = nil
        proxy.stop(id)
        store.config.instances.removeAll { $0.id == id }
    }
}

private struct InstanceForm: View {
    @EnvironmentObject private var store: ConfigStore
    @Binding var instance: ProxyInstance

    private var portConflict: Bool {
        store.config.instances.contains { $0.id != instance.id && $0.port == instance.port }
    }

    var body: some View {
        Form {
            Section {
                TextField("顯示名稱", text: $instance.name)
                Picker("環境", selection: $instance.environmentID) {
                    ForEach(store.config.environments) { environment in
                        Text(environment.name).tag(environment.id)
                    }
                }
                Picker("資料庫類型", selection: $instance.databaseTypeID) {
                    ForEach(store.config.databaseTypes) { type in
                        Text(type.name).tag(type.id)
                    }
                }
            } footer: {
                Text("環境和資料庫類型可以在上方的分頁新增。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                TextField("Instance 連線名稱", text: $instance.connectionName, prompt: Text("project:region:instance"))
                    .font(.system(size: 12, design: .monospaced))
                TextField("本機 Port", value: $instance.port, format: .number.grouping(.never))
                if portConflict {
                    Text("這個 port 已經被另一個連線使用，兩者無法同時開啟。")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Toggle("開啟 Portside 時自動連線", isOn: $instance.autoStart)
            }

            Section("實際執行的指令") {
                Text("cloud-sql-proxy '\(instance.connectionName)?port=\(String(instance.port))'")
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 環境

private struct EnvironmentsTab: View {
    @EnvironmentObject private var store: ConfigStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                ForEach(store.config.environments) { environment in
                    EnvironmentRow(
                        environment: binding(for: environment.id),
                        canDelete: !isInUse(environment.id),
                        onDelete: { store.config.environments.removeAll { $0.id == environment.id } }
                    )
                }
            }
            Divider()
            HStack {
                Button {
                    store.config.environments.append(DBEnvironment(name: "新環境", colorHex: "#5856D6"))
                } label: {
                    Label("新增環境", systemImage: "plus")
                }
                Spacer()
                Text("有連線正在使用的環境無法刪除。勾選「啟動前確認」的環境，連線前會先跳出確認視窗。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(10)
        }
    }

    private func isInUse(_ id: UUID) -> Bool {
        store.config.instances.contains { $0.environmentID == id }
    }

    private func binding(for id: UUID) -> Binding<DBEnvironment> {
        Binding(
            get: { store.config.environments.first { $0.id == id } ?? DBEnvironment(name: "", colorHex: "#8E8E93") },
            set: { updated in
                if let index = store.config.environments.firstIndex(where: { $0.id == id }) {
                    store.config.environments[index] = updated
                }
            }
        )
    }
}

private struct EnvironmentRow: View {
    @Binding var environment: DBEnvironment
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ColorPicker(
                "顏色",
                selection: Binding(
                    get: { Color(hex: environment.colorHex) },
                    set: { environment.colorHex = $0.hexString }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
            TextField("名稱", text: $environment.name)
                .textFieldStyle(.roundedBorder)
            Toggle("啟動前確認", isOn: $environment.confirmBeforeConnect)
                .toggleStyle(.checkbox)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(!canDelete)
            .help(canDelete ? "刪除環境" : "有連線正在使用這個環境")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 資料庫類型

private struct DatabaseTypesTab: View {
    @EnvironmentObject private var store: ConfigStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                ForEach(store.config.databaseTypes) { type in
                    DatabaseTypeRow(
                        type: binding(for: type.id),
                        canDelete: !isInUse(type.id),
                        onDelete: { store.config.databaseTypes.removeAll { $0.id == type.id } }
                    )
                }
            }
            Divider()
            HStack {
                Button {
                    store.config.databaseTypes.append(DatabaseType(name: "MySQL", defaultPort: 3306))
                } label: {
                    Label("新增資料庫類型", systemImage: "plus")
                }
                Spacer()
                Text("資料庫類型用來分組，並決定新連線的預設 port。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
        }
    }

    private func isInUse(_ id: UUID) -> Bool {
        store.config.instances.contains { $0.databaseTypeID == id }
    }

    private func binding(for id: UUID) -> Binding<DatabaseType> {
        Binding(
            get: { store.config.databaseTypes.first { $0.id == id } ?? DatabaseType(name: "", defaultPort: 0) },
            set: { updated in
                if let index = store.config.databaseTypes.firstIndex(where: { $0.id == id }) {
                    store.config.databaseTypes[index] = updated
                }
            }
        )
    }
}

private struct DatabaseTypeRow: View {
    @Binding var type: DatabaseType
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("名稱", text: $type.name)
                .textFieldStyle(.roundedBorder)
            Text("預設 port")
                .foregroundStyle(.secondary)
            TextField("預設 port", value: $type.defaultPort, format: .number.grouping(.never))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .frame(width: 80)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(!canDelete)
            .help(canDelete ? "刪除資料庫類型" : "有連線正在使用這個類型")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 一般

private struct GeneralTab: View {
    @EnvironmentObject private var store: ConfigStore
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        Form {
            Section {
                TextField(
                    "gcloud",
                    text: $store.config.gcloudPath,
                    prompt: Text(ToolLocator.find("gcloud") ?? "找不到，請填寫完整路徑")
                )
                TextField(
                    "cloud-sql-proxy",
                    text: $store.config.proxyPath,
                    prompt: Text(ToolLocator.find("cloud-sql-proxy") ?? "找不到，請填寫完整路徑")
                )
            } header: {
                Text("工具路徑")
            } footer: {
                Text("留空會自動搜尋 Homebrew 和 Google Cloud SDK 的常見安裝位置。可以在終端機用 which gcloud 查詢路徑。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("驗證") {
                Button("立即檢查 Google 驗證") { Task { await auth.check() } }
            }

            Section("設定檔") {
                Text(store.fileURL.path)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                Button("在 Finder 顯示") {
                    NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
                }
            }
        }
        .formStyle(.grouped)
    }
}
