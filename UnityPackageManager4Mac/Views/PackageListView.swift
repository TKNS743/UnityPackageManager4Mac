import SwiftUI

struct PackageListView: View {
    @EnvironmentObject var store: PackageStore
    let packages: [UnityPackage]
    @Binding var selectedID: UUID?
    @Binding var search: String

    @State private var sortOrder: SortOrder = .nameAsc
    @State private var showMissingOnly: Bool = false
    @State private var deleteTarget: UnityPackage? = nil
    @State private var showDeleteConfirm = false

    enum SortOrder: String, CaseIterable {
        case nameAsc    = "名前 ↑"
        case nameDesc   = "名前 ↓"
        case dateDesc   = "追加日 ↓"
        case dateAsc    = "追加日 ↑"
        case folder     = "フォルダ"
    }

    var missingCount: Int {
        packages.filter { store.isMissing($0) }.count
    }

    var filtered: [UnityPackage] {
        showMissingOnly ? packages.filter { store.isMissing($0) } : packages
    }

    var sorted: [UnityPackage] {
        switch sortOrder {
        case .nameAsc:  return filtered.sorted { $0.name < $1.name }
        case .nameDesc: return filtered.sorted { $0.name > $1.name }
        case .dateDesc: return filtered.sorted { $0.addedAt > $1.addedAt }
        case .dateAsc:  return filtered.sorted { $0.addedAt < $1.addedAt }
        case .folder:   return filtered.sorted { $0.folder < $1.folder }
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

            // ── 欠損ファイル警告バナー ──
            if missingCount > 0 {
                Button {
                    showMissingOnly.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(showMissingOnly
                             ? "欠損 \(missingCount) 件を表示中（タップで全表示）"
                             : "ファイルが見つからないパッケージが \(missingCount) 件あります")
                            .font(.caption)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: showMissingOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.orange.opacity(0.12))
                }
                .buttonStyle(.plain)
                Divider()
            }

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
                    PackageRowView(packageID: pkg.id)
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
    @EnvironmentObject var store: PackageStore
    let packageID: UUID

    private var package: UnityPackage? {
        store.packages.first { $0.id == packageID }
    }

    var body: some View {
        if let package = package {
            HStack(spacing: 10) {
                // サムネイル
                if let thumbURL = package.thumbnailURL, let url = URL(string: thumbURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            thumbnailPlaceholder
                        case .empty:
                            Color(nsColor: .controlBackgroundColor)
                                .overlay(ProgressView().scaleEffect(0.5))
                        @unknown default:
                            thumbnailPlaceholder
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    thumbnailPlaceholder
                        .frame(width: 44, height: 44)
                }

                // テキスト情報
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(package.name)
                            .font(.headline)
                            .lineLimit(1)
                        if store.missingPackages.contains(packageID) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .help("ファイルが見つかりません")
                        }
                    }

                    HStack(spacing: 6) {
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
            }
            .padding(.vertical, 2)
        }
    }

    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.accentColor.opacity(0.1))
            .overlay(
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(Color.accentColor.opacity(0.3))
            )
    }
}
