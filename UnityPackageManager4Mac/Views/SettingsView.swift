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
    @State private var pendingOutputDirectory: String? = nil
    @State private var showMoveConfirm = false

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
        .confirmationDialog(
            "整理先フォルダを変更します",
            isPresented: $showMoveConfirm,
            titleVisibility: .visible
        ) {
            Button("既存ファイルを新しい整理先へ移動する") {
                if let path = pendingOutputDirectory {
                    store.changeOutputDirectory(to: path, moveFiles: true)
                }
            }
            Button("既存ファイルは移動せず変更のみ") {
                if let path = pendingOutputDirectory {
                    store.changeOutputDirectory(to: path, moveFiles: false)
                }
            }
            Button("キャンセル", role: .cancel) {
                pendingOutputDirectory = nil
            }
        } message: {
            let count = store.packages.filter { !$0.filePath.isEmpty }.count
            if count > 0 {
                Text("\(count)件のパッケージが登録されています。\n\n「既存ファイルは移動せず変更のみ」を選択した場合、ファイルは元の場所に残ります。次回起動時に「ファイルが見つからない」として検知されますのでご注意ください。")
            } else {
                Text("整理先フォルダを変更します。")
            }
        }
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
        // 登録済みパッケージがある場合は確認ダイアログを出す
        if !store.packages.filter({ !$0.filePath.isEmpty }).isEmpty {
            pendingOutputDirectory = url.path
            showMoveConfirm = true
        } else {
            store.changeOutputDirectory(to: url.path, moveFiles: false)
        }
    }
}

// MARK: - Folder Management

struct FolderManagementView: View {
    @EnvironmentObject var store: PackageStore
    @State private var newFolderName = ""
    @State private var selection: String?
    @State private var folderToDelete: String? = nil
    @State private var showDeleteConfirm = false

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
                        folderToDelete = selected
                        showDeleteConfirm = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Text("フォルダを選択すると削除できます")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .padding()
            .frame(minWidth: 220)
            .confirmationDialog(
                "「\(folderToDelete ?? "")」を削除しますか？",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("フォルダ内のデータも削除する", role: .destructive) {
                    if let name = folderToDelete {
                        store.deleteFolderWithPackages(name)
                        selection = nil
                    }
                }
                Button("フォルダ内のデータはそのままにする") {
                    if let name = folderToDelete {
                        store.deleteFolderKeepPackages(name)
                        selection = nil
                    }
                }
                Button("キャンセル", role: .cancel) {
                    folderToDelete = nil
                }
            } message: {
                let count = store.packages.filter { $0.folder == (folderToDelete ?? "") }.count
                Text(count > 0
                     ? "\(count)件のパッケージが含まれています。データはそのままにする場合は「未分類」カテゴリへ移動されます。"
                     : "このフォルダにはパッケージがありません。")
            }
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
                Text("データは Application Support 内に保存されています。")
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
