import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: PackageStore

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("一般", systemImage: "gearshape")
                }
            FolderManagementView()
                .tabItem {
                    Label("フォルダ管理", systemImage: "folder")
                }
            DataSettingsView()
                .tabItem {
                    Label("データ管理", systemImage: "internaldrive")
                }
        }
        .frame(width: 520, height: 400)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var store: PackageStore

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    if store.settings.outputDirectory.isEmpty {
                        Label("出力フォルダが設定されていません", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    } else {
                        Text(store.settings.outputDirectory)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack {
                        Button("フォルダを変更...") { pickOutputDirectory() }
                            .buttonStyle(.bordered)
                        if !store.settings.outputDirectory.isEmpty {
                            Button("Finderで開く") { store.openOutputDirectory() }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            } header: {
                Text("整理先フォルダ")
            } footer: {
                Text("パッケージ追加時に自動でこのフォルダへ整理されます。\n構成例: [整理先フォルダ] / [フォルダ名] / パッケージ名 / ファイル.unitypackage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func pickOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "選択"
        panel.message = "整理先フォルダを選択してください"
        if !store.settings.outputDirectory.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: store.settings.outputDirectory)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.settings.outputDirectory = url.path
        store.save()
    }
}

// MARK: - Folder Management

struct FolderManagementView: View {
    @EnvironmentObject var store: PackageStore
    @State private var newFolderName = ""
    @State private var selection: String?

    var body: some View {
        HSplitView {
            List(store.settings.folders, id: \.self, selection: $selection) { folder in
                Text(folder).tag(folder)
            }
            .frame(minWidth: 150)

            VStack(alignment: .leading, spacing: 14) {
                Text("フォルダ管理")
                    .font(.headline)

                HStack {
                    TextField("新しいフォルダ名", text: $newFolderName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addFolder() }
                    Button("追加") { addFolder() }
                        .buttonStyle(.bordered)
                        .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Divider()

                if let selected = selection {
                    HStack {
                        Image(systemName: "folder.fill").foregroundStyle(Color.accentColor)
                        Text(selected).fontWeight(.medium)
                    }
                    Button("「\(selected)」を削除", role: .destructive) {
                        store.deleteFolder(selected)
                        selection = nil
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Text("フォルダを選択すると削除できます")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Text("※ フォルダを削除しても登録済みパッケージには影響しません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(minWidth: 220)
        }
    }

    private func addFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        store.addFolder(name)
        newFolderName = ""
    }
}

// MARK: - Data Settings

struct DataSettingsView: View {
    @EnvironmentObject var store: PackageStore
    @State private var showResetPackagesConfirm = false
    @State private var showResetAllConfirm = false

    private var appSupportDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("UnityPackageManager")
    }
    private var packagesPath: String { appSupportDir.appendingPathComponent("packages.json").path }
    private var settingsPath: String { appSupportDir.appendingPathComponent("settings.json").path }

    var body: some View {
        Form {
            // 保存場所
            Section {
                dataRow(label: "パッケージデータ", path: packagesPath)
                dataRow(label: "設定ファイル", path: settingsPath)

                Button("フォルダをFinderで開く") {
                    NSWorkspace.shared.open(appSupportDir)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)

            } header: {
                Text("保存場所")
            } footer: {
                Text("データは Application Support 内に保存されています。\n ※上級者向け バックアップが必要な場合はこのファイルをコピーしてください。復元する際は整理先ディレクトリをバックアップ時と同じにしてください。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            // リセット
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    // パッケージ一覧のみリセット
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("パッケージ一覧をリセット")
                                .fontWeight(.medium)
                            Text("登録済みパッケージをすべて削除します。整理先のファイルはそのまま残ります。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("リセット") { showResetPackagesConfirm = true }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                    }

                    Divider()

                    // 全データリセット
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("すべての設定をリセット")
                                .fontWeight(.medium)
                            Text("パッケージ一覧・フォルダ設定・整理先フォルダをすべて初期化します。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("完全リセット") { showResetAllConfirm = true }
                            .buttonStyle(.bordered)
                            .tint(.red)
                    }
                }
            } header: {
                Text("リセット")
            }
        }
        .formStyle(.grouped)
        // パッケージのみリセット
        .confirmationDialog(
            "パッケージ一覧をリセットしますか？",
            isPresented: $showResetPackagesConfirm,
            titleVisibility: .visible
        ) {
            Button("リセットする", role: .destructive) {
                store.resetPackages()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("登録済みパッケージがすべて削除されます。整理先のファイルには影響しません。")
        }
        // 完全リセット
        .confirmationDialog(
            "すべての設定を初期化しますか？",
            isPresented: $showResetAllConfirm,
            titleVisibility: .visible
        ) {
            Button("完全リセットする", role: .destructive) {
                store.resetAll()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("パッケージ一覧・フォルダ・整理先フォルダがすべてリセットされます。次回起動時に初期設定が行われます。")
        }
    }

    @ViewBuilder
    private func dataRow(label: String, path: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(path)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.head)
        }
        .padding(.vertical, 2)
    }
}
