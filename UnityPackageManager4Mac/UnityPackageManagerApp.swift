import SwiftUI

@main
struct UnityPackageManagerApp: App {
    @StateObject private var store = PackageStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1200, minHeight: 800)
                .onAppear {
                    // 初回起動 or 出力フォルダ未設定なら選択ダイアログを表示
                    if store.needsOutputDirectorySetup {
                        store.runFirstLaunchSetup()
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button("パッケージを追加...") {
                    NotificationCenter.default.post(name: .addPackage, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                // エクスポートとインポート機能はもう少し仕様の詰めが必要なのでオミット
                // Divider()
                //
                // Button("CSVをエクスポート") {
                //     NotificationCenter.default.post(name: .exportCSV, object: nil)
                // }
                // .keyboardShortcut("e", modifiers: [.command, .shift])
                //
                // Button("CSVをインポート...") {
                //     NotificationCenter.default.post(name: .importCSV, object: nil)
                // }
                // .keyboardShortcut("i", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}

extension Notification.Name {
    static let addPackage     = Notification.Name("addPackage")
    static let packageUpdated = Notification.Name("packageUpdated")
    // エクスポートとインポート機能はもう少し仕様の詰めが必要なのでオミット
    // static let exportCSV  = Notification.Name("exportCSV")
    // static let importCSV  = Notification.Name("importCSV")
}
