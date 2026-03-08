//
//  openAIMApp.swift
//  openAIM
//
//  Created by slioner on 2026/3/7.
//

import SwiftUI

@main
struct openAIMApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appViewModel)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    setupWindowDelegate()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit OpenAIM") {
                    AppDelegate.shared?.confirmAndQuit()
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }

    private func setupWindowDelegate() {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                window.delegate = appDelegate
            }
        }
    }
}

/// 应用代理 - 处理退出确认
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static var shared: AppDelegate?
    private var shouldConfirmQuit = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard shouldConfirmQuit else { return true }

        // 异步显示确认对话框，先返回 false 阻止窗口关闭
        DispatchQueue.main.async { [weak self] in
            self?.showQuitConfirmation()
        }
        return false
    }

    private func showQuitConfirmation() {
        let alert = NSAlert()
        alert.messageText = "确认退出"
        alert.informativeText = "确定要退出 OpenAIM 吗？"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "退出")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            shouldConfirmQuit = false
            NSApplication.shared.terminate(nil)
        }
        // 用户取消，窗口保持打开状态
    }

    // MARK: - NSApplicationDelegate

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if shouldConfirmQuit {
            showQuitConfirmation()
            return .terminateCancel
        }
        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    /// 显示退出确认对话框（公开方法）
    func confirmAndQuit() {
        showQuitConfirmation()
    }
}

/// 根视图 - 根据认证状态切换视图
struct RootView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        switch appViewModel.currentView {
        case .login:
            LoginView()
        case .register:
            RegisterView()
        default:
            // 已认证视图 - 带导航栏
            HStack(spacing: 0) {
                NavigationRail()
                
                switch appViewModel.currentView {
                case .main:
                    MainView()
                case .contacts:
                    ContactsView()
                case .agents:
                    AgentListView()
                case .organizations:
                    OrganizationView()
                case .settings:
                    SettingsView()
                default:
                    MainView()
                }
            }
        }
    }
}