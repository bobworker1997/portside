import AppKit
import SwiftUI

struct MenuPanelView: View {
    @EnvironmentObject private var store: ConfigStore
    @EnvironmentObject private var proxy: ProxyManager
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            AuthCard()

            if store.config.instances.isEmpty {
                emptyState
            } else {
                ForEach(store.config.databaseTypes) { type in
                    let items = store.config.instances.filter { $0.databaseTypeID == type.id }
                    if !items.isEmpty {
                        InstanceGroup(title: type.name, instances: items)
                    }
                }
            }

            Divider()
            footer
        }
        .padding(14)
        .frame(width: 360)
    }

    private var header: some View {
        HStack {
            Image(systemName: "bolt.horizontal.circle.fill")
                .font(.system(size: 20))
            Text("Portside")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Button {
                SettingsWindowController.shared.show()
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.borderless)
            .help("設定")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("尚未設定連線")
                .font(.system(size: 13, weight: .semibold))
            Text("到設定新增 Cloud SQL instance 後，就能在這裡開關。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("開啟設定") { SettingsWindowController.shared.show() }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private var footer: some View {
        HStack {
            Text("\(proxy.runningCount) 個連線執行中")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Button("全部停止") { proxy.stopAll() }
                .buttonStyle(.borderless)
                .disabled(proxy.runningCount == 0)
            Button("結束") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
        }
    }
}

private struct AuthCard: View {
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                icon
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if auth.state == .valid {
                    Button("重新登入") { auth.login() }.buttonStyle(.borderless)
                }
            }
            action
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(auth.state == .expired ? Color.orange.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
        )
    }

    @ViewBuilder private var icon: some View {
        switch auth.state {
        case .valid:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.system(size: 20))
        case .expired, .toolMissing:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.system(size: 20))
        case .loggingIn, .checking:
            ProgressView().controlSize(.small)
        case .unknown:
            Image(systemName: "questionmark.circle").foregroundStyle(.secondary).font(.system(size: 20))
        }
    }

    private var title: String {
        switch auth.state {
        case .valid: return "Google 驗證有效"
        case .expired: return "Google 驗證已過期"
        case .loggingIn: return "等待瀏覽器完成登入…"
        case .checking: return "正在檢查驗證狀態…"
        case .unknown: return "尚未確認驗證狀態"
        case .toolMissing: return "找不到 gcloud"
        }
    }

    private var subtitle: String {
        switch auth.state {
        case .valid:
            if let date = auth.lastChecked {
                return "上次檢查 " + date.formatted(date: .omitted, time: .shortened)
            }
            return "Application Default Credentials"
        case .expired: return "連線已暫停。重新登入後會自動恢復。"
        case .loggingIn: return "請在瀏覽器完成 Google 登入。"
        case .checking: return "執行 gcloud 確認中。"
        case .unknown: return "可能是網路問題，稍後會再檢查一次。"
        case .toolMissing: return "請到設定的「一般」分頁指定 gcloud 路徑。"
        }
    }

    @ViewBuilder private var action: some View {
        switch auth.state {
        case .expired:
            Button {
                auth.login()
            } label: {
                Text("在瀏覽器重新登入").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        case .loggingIn:
            Button("取消") { auth.cancelLogin() }
        case .unknown:
            Button("重新檢查") { Task { await auth.check() } }
        case .toolMissing:
            Button("開啟設定") { SettingsWindowController.shared.show() }
        case .valid, .checking:
            EmptyView()
        }
    }
}

private struct InstanceGroup: View {
    let title: String
    let instances: [ProxyInstance]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                ForEach(Array(instances.enumerated()), id: \.element.id) { index, instance in
                    InstanceRow(instance: instance)
                    if index < instances.count - 1 {
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        }
    }
}

private struct InstanceRow: View {
    @EnvironmentObject private var store: ConfigStore
    @EnvironmentObject private var proxy: ProxyManager
    @EnvironmentObject private var auth: AuthManager
    let instance: ProxyInstance

    private var status: ProxyStatus { proxy.status(of: instance.id) }
    private var environment: DBEnvironment? { store.environment(instance.environmentID) }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(instance.name)
                        .font(.system(size: 13, weight: .semibold))
                    if let environment {
                        Text(environment.name.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color(hex: environment.colorHex)))
                    }
                }
                Text(statusText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(statusColor)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: toggleBinding)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var statusText: String {
        let address = "localhost:\(instance.port)"
        switch status {
        case .stopped: return "未啟動 · \(address)"
        case .starting: return "啟動中… · \(address)"
        case .running: return "已連線 · \(address)"
        case .paused: return "等待驗證 · \(address)"
        case .failed(let message): return message
        }
    }

    private var statusColor: Color {
        switch status {
        case .failed: return .red
        case .paused: return .orange
        default: return .secondary
        }
    }

    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { status.isOn },
            set: { isOn in
                if isOn {
                    DispatchQueue.main.async { requestStart() }
                } else {
                    proxy.stop(instance.id)
                }
            }
        )
    }

    private func requestStart() {
        if let environment, environment.confirmBeforeConnect {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "要連線到「\(instance.name)」嗎？"
            alert.informativeText = "這是 \(environment.name) 環境，會在 localhost:\(instance.port) 開啟連線。"
            alert.addButton(withTitle: "連線")
            alert.addButton(withTitle: "取消")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        if auth.state == .expired || auth.state == .loggingIn {
            proxy.queueUntilAuthenticated(instance.id)
        } else {
            proxy.start(instance)
        }
    }
}
