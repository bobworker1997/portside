import AppKit

@MainActor
enum ConnectionConfirmation {
    /// 環境有勾「啟動前確認」時跳出確認視窗。回傳 true 代表可以連線。
    /// 手動開關和開啟 app 時的自動連線都必須經過這裡，避免自動連線繞過確認。
    static func confirm(_ instance: ProxyInstance, note: String? = nil) -> Bool {
        guard let environment = ConfigStore.shared.environment(instance.environmentID),
              environment.confirmBeforeConnect else { return true }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "要連線到「\(instance.name)」嗎？"
        var info = "這是 \(environment.name) 環境，會在 localhost:\(instance.port) 開啟連線。"
        if let note { info = note + "\n\n" + info }
        alert.informativeText = info
        alert.addButton(withTitle: "連線")
        alert.addButton(withTitle: "取消")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
