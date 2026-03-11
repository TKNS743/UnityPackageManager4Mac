import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: PackageStore
    @Binding var folderFilter: String
    @State private var showAddFolder = false
    @State private var newFolderName = ""

    var folderCounts: [String: Int] {
        Dictionary(grouping: store.packages, by: { $0.folder })
            .mapValues { $0.count }
    }

    var body: some View {
        List(selection: $folderFilter) {
            // ── すべて ──
            Label("すべて", systemImage: "tray.2")
                .badge(store.packages.count)
                .tag("ALL")

            Divider()

            // ── フォルダ一覧 ──
            Section("フォルダ") {
                ForEach(store.allFolders, id: \.self) { folder in
                    FolderRowView(
                        folder: folder,
                        count: folderCounts[folder] ?? 0,
                        canDelete: store.settings.folders.contains(folder)
                    )
                    .tag(folder)
                }

                // 新規フォルダ追加フォーム
                if showAddFolder {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                            .foregroundStyle(Color.accentColor)
                        TextField("フォルダ名", text: $newFolderName)
                            .onSubmit { commitNewFolder() }
                        Button(action: commitNewFolder) {
                            Image(systemName: "checkmark")
                        }
                        .buttonStyle(.plain)
                        .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Button {
                showAddFolder.toggle()
                newFolderName = ""
            } label: {
                Label(showAddFolder ? "キャンセル" : "フォルダを追加", systemImage: showAddFolder ? "xmark" : "folder.badge.plus")
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .navigationTitle("Unity Package Manager")
        .frame(minWidth: 180)
    }

    private func commitNewFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        store.addFolder(name)
        newFolderName = ""
        showAddFolder = false
    }
}

struct FolderRowView: View {
    @EnvironmentObject var store: PackageStore
    let folder: String
    let count: Int
    let canDelete: Bool

    @State private var showDeleteConfirm = false

    var body: some View {
        Label(folder, systemImage: "folder")
            .badge(count)
            .contextMenu {
                if canDelete {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("フォルダを削除", systemImage: "trash")
                    }
                }
            }
            .confirmationDialog(
                "「\(folder)」を削除しますか？",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("フォルダ内のデータも削除する", role: .destructive) {
                    store.deleteFolderWithPackages(folder)
                }
                Button("フォルダ内のデータはそのままにする") {
                    store.deleteFolderKeepPackages(folder)
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                let c = store.packages.filter { $0.folder == folder }.count
                Text(c > 0
                     ? "\(c)件のパッケージが含まれています。そのままにする場合は「未分類」へ移動されます。"
                     : "このフォルダにはパッケージがありません。")
            }
    }
}
