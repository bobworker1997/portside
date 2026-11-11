import AppKit
import SwiftUI

@main
struct PortsideApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ConfigStore.shared
    @StateObject private var proxy = ProxyManager.shared
    @StateObject private var auth = AuthManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuPanelView()
                .environmentObject(store)
                .environmentObject(proxy)
                .environmentObject(auth)
        } label: {
            Image(systemName: menuIcon)
        }
        .menuBarExtraStyle(.window)
    }

    /// 選單列圖示：驗證過期顯示警告；有「需要確認」的環境（例如 Production）連線中時用實心圖示
    private var menuIcon: String {
        if auth.state == .expired { return "exclamationmark.triangle.fill" }
        let sensitiveActive = store.config.instances.contains { instance in
            proxy.status(of: instance.id).isOn
                && (store.environment(instance.environmentID)?.confirmBeforeConnect ?? false)
        }
        if sensitiveActive { return "bolt.horizontal.circle.fill" }
        return proxy.runningCount > 0 ? "bolt.horizontal.circle" : "bolt.horizontal"
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installEditMenuIfNeeded()

        AuthManager.shared.startMonitoring()
        Task { @MainActor in
            await AuthManager.shared.check()
            guard AuthManager.shared.state != .expired else { return }
            for instance in ConfigStore.shared.config.instances where instance.autoStart {
                ProxyManager.shared.start(instance)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        ProxyManager.shared.terminateAllNow()
    }

    /// 沒有主選單時，文字欄位的 ⌘C / ⌘V 不會作用，所以補一個最小的編輯選單
    private func installEditMenuIfNeeded() {
        if let items = NSApp.mainMenu?.items, items.count >= 2 { return }

        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "結束 Portside", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "編輯")
        editMenu.addItem(withTitle: "還原", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪下", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷貝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "貼上", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全選", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }
}

/// 設定視窗用 AppKit 自己管理，避免 SwiftUI 的 Window scene 在啟動時自動打開
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    private init() {}

    func show() {
        if window == nil {
            let root = SettingsView()
                .environmentObject(ConfigStore.shared)
                .environmentObject(ProxyManager.shared)
                .environmentObject(AuthManager.shared)
            let created = NSWindow(contentViewController: NSHostingController(rootView: root))
            created.title = "Portside 設定"
            created.styleMask = [.titled, .closable, .miniaturizable]
            created.isReleasedWhenClosed = false
            created.setContentSize(NSSize(width: 740, height: 500))
            created.center()
            window = created
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }

    var hexString: String {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return "#8E8E93" }
        return String(
            format: "#%02X%02X%02X",
            Int((color.redComponent * 255).rounded()),
            Int((color.greenComponent * 255).rounded()),
            Int((color.blueComponent * 255).rounded())
        )
    }
}
