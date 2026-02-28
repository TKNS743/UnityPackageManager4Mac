import SwiftUI

struct PackageDetailView: View {
    @EnvironmentObject var store: PackageStore
    let packageID: UUID
    @Binding var selectedID: UUID?
    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    /// ストアから常に最新のパッケージを取得
    private var package: UnityPackage? {
        store.packages.first { $0.id == packageID }
    }

    var body: some View {
        if let package = package {
            detail(package: package)
        }
    }

    @ViewBuilder
    private func detail(package: UnityPackage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header ──
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        // サムネイル
                    if let thumbURL = package.thumbnailURL, let url = URL(string: thumbURL) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color(nsColor: .controlBackgroundColor)
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Text(package.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        HStack(spacing: 8) {
                            Label(package.folder, systemImage: "folder.fill")
                                .font(.callout)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.15), in: Capsule())
                                .foregroundStyle(Color.accentColor)

                            Text({
                                let f = DateFormatter(); f.dateFormat = "yyyy年MM月dd日"
                                return f.string(from: package.addedAt)
                            }())
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Button { showEdit = true } label: {
                            Label("編集", systemImage: "pencil")
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                .padding(24)

                Divider()

                // ── Info ──
                VStack(alignment: .leading, spacing: 20) {

                    // ファイル情報
                    GroupBox("ファイル情報") {
                        VStack(alignment: .leading, spacing: 12) {
                            if !package.fileName.isEmpty {
                                DetailRow(label: "ファイル名", value: package.fileName, mono: true)
                            }
                            if !package.filePath.isEmpty {
                                DetailRow(label: "保存場所", value: package.filePath, mono: true)
                                Button {
                                    store.revealInFinder(package)
                                } label: {
                                    Label("Finderで表示", systemImage: "folder")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            } else {
                                Label("ファイルが未登録です", systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(.orange)
                                    .font(.callout)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // 販売ページ
                    if !package.url.isEmpty {
                        GroupBox("販売ページ") {
                            VStack(alignment: .leading, spacing: 8) {
                                // 保存済みページタイトル（登録時に取得済みの場合のみ表示）
                                if let title = package.pageTitle {
                                    HStack(spacing: 6) {
                                        Image(systemName: "text.quote")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(title)
                                            .font(.callout)
                                            .fontWeight(.medium)
                                            .textSelection(.enabled)
                                    }
                                    Divider()
                                }
                                // URL + 開くボタン
                                HStack {
                                    Text(package.url)
                                        .font(.callout)
                                        .foregroundStyle(.blue)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    if let url = URL(string: package.url) {
                                        Button {
                                            NSWorkspace.shared.open(url)
                                        } label: {
                                            Label("開く", systemImage: "safari")
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }
                            }
                        }
                    }

                    // 備考
                    if !package.notes.isEmpty {
                        GroupBox("備考") {
                            Text(package.notes)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // 追加ファイル・フォルダ
                    if !package.additionalPaths.isEmpty {
                        GroupBox("追加ファイル・フォルダ") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(package.additionalPaths, id: \.self) { path in
                                    HStack(spacing: 6) {
                                        let isDir: Bool = {
                                            var d: ObjCBool = false
                                            FileManager.default.fileExists(atPath: path, isDirectory: &d)
                                            return d.boolValue
                                        }()
                                        Image(systemName: isDir ? "folder.fill" : "doc.fill")
                                            .foregroundStyle(isDir ? .yellow : Color.accentColor)
                                        Text(URL(fileURLWithPath: path).lastPathComponent)
                                            .font(.callout)
                                        Spacer()
                                        Text(path)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                            .truncationMode(.head)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // フォルダ構成プレビュー
                    GroupBox("フォルダ構成プレビュー") {
                        let outputDir = store.settings.outputDirectory
                        let root = URL(fileURLWithPath: outputDir).lastPathComponent
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.fill").foregroundStyle(.yellow)
                                Text(root).bold()
                            }
                            HStack(spacing: 4) {
                                Spacer().frame(width: 20)
                                Image(systemName: "folder.fill").foregroundStyle(.yellow)
                                Text(package.folder).foregroundStyle(.secondary)
                            }
                            HStack(spacing: 4) {
                                Spacer().frame(width: 40)
                                Image(systemName: "folder.fill").foregroundStyle(.yellow)
                                Text(package.name).foregroundStyle(.secondary)
                            }
                            HStack(spacing: 4) {
                                Spacer().frame(width: 60)
                                Image(systemName: "shippingbox.fill").foregroundStyle(Color.accentColor)
                                Text(package.fileName.isEmpty ? package.name + ".unitypackage" : package.fileName)
                                    .fontDesign(.monospaced)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .font(.callout)
                        .padding(4)
                    }
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showEdit) {
            PackageFormView(mode: .edit(package))
        }
        .confirmationDialog(
            "「\(package.name)」を削除しますか？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("リストからのみ削除", role: .destructive) {
                store.deleteFromList(package)
                selectedID = nil
            }
            Button("ファイルも削除（整理先フォルダごと）", role: .destructive) {
                store.deleteWithFile(package)
                selectedID = nil
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("「リストからのみ削除」はファイルをそのまま残します。\n「ファイルも削除」は整理先の「パッケージ名フォルダ」をまるごと削除します。")
        }
    } // detail()
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    var mono: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(mono ? .system(.callout, design: .monospaced) : .callout)
                .textSelection(.enabled)
        }
    }
}
