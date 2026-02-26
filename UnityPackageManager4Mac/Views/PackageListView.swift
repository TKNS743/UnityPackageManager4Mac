import SwiftUI

struct PackageListView: View {
    @EnvironmentObject var store: PackageStore
    let packages: [UnityPackage]
    @Binding var selectedID: UUID?
    @Binding var search: String

    @State private var sortOrder: SortOrder = .nameAsc
    @State private var deleteTarget: UnityPackage? = nil
    @State private var showDeleteConfirm = false

    enum SortOrder: String, CaseIterable {
        case nameAsc    = "名前 ↑"
        case nameDesc   = "名前 ↓"
        case dateDesc   = "追加日 ↓"
        case dateAsc    = "追加日 ↑"
        case folder     = "フォルダ"
    }

    var sorted: [UnityPackage] {
        switch sortOrder {
        case .nameAsc:  return packages.sorted { $0.name < $1.name }
        case .nameDesc: return packages.sorted { $0.name > $1.name }
        case .dateDesc: return packages.sorted { $0.addedAt > $1.addedAt }
        case .dateAsc:  return packages.sorted { $0.addedAt < $1.addedAt }
        case .folder:   return packages.sorted { $0.folder < $1.folder }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("検索...", text: $search)
                    .textFieldStyle(.plain)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if sorted.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 40, weight: .thin))
                        .foregroundStyle(.quaternary)
                    Text(search.isEmpty ? "パッケージがありません" : "一致するパッケージなし")
                        .foregroundStyle(.secondary)
                    if search.isEmpty {
                        Text("「＋」ボタンから追加してください")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(sorted, selection: $selectedID) { pkg in
                    PackageRowView(package: pkg)
                        .tag(pkg.id)
                        .contextMenu {
                            packageContextMenu(pkg)
                        }
                }
                .listStyle(.plain)
            }

            Divider()

            // Footer
            HStack {
                Text("\(sorted.count)件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("並び替え", selection: $sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)
                .labelsHidden()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .confirmationDialog(
            deleteTarget.map { "「\($0.name)」を削除しますか？" } ?? "",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            if let pkg = deleteTarget {
                Button("リストからのみ削除", role: .destructive) {
                    store.deleteFromList(pkg)
                    if selectedID == pkg.id { selectedID = nil }
                }
                Button("ファイルも削除（整理先フォルダごと）", role: .destructive) {
                    store.deleteWithFile(pkg)
                    if selectedID == pkg.id { selectedID = nil }
                }
                Button("キャンセル", role: .cancel) {}
            }
        } message: {
            if let pkg = deleteTarget {
                Text("「リストからのみ削除」はファイルをそのまま残します。\n「ファイルも削除」は整理先の「パッケージ名フォルダ」をまるごと削除します。")
            }
        }
    }

    @ViewBuilder
    private func packageContextMenu(_ pkg: UnityPackage) -> some View {
        Button {
            selectedID = pkg.id
        } label: {
            Label("詳細を表示", systemImage: "info.circle")
        }

        if !pkg.filePath.isEmpty {
            Button {
                store.revealInFinder(pkg)
            } label: {
                Label("Finderで表示", systemImage: "folder")
            }
        }

        if !pkg.url.isEmpty, let url = URL(string: pkg.url) {
            Divider()
            Button {
                NSWorkspace.shared.open(url)
            } label: {
                Label("販売ページを開く", systemImage: "safari")
            }
        }

        Divider()
        Button(role: .destructive) {
            deleteTarget = pkg
            showDeleteConfirm = true
        } label: {
            Label("削除...", systemImage: "trash")
        }
    }
}

// MARK: - Row

struct PackageRowView: View {
    let package: UnityPackage

    private var dateString: String {
        let f = DateFormatter(); f.dateFormat = "yyyy/MM/dd"
        return f.string(from: package.addedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(package.name)
                .font(.headline)
                .lineLimit(1)

            HStack(spacing: 6) {
                // Folder badge
                Text(package.folder)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.accentColor)

                if !package.fileName.isEmpty {
                    Text(package.fileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            if !package.notes.isEmpty {
                Text(package.notes)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
