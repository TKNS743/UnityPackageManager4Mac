import SwiftUI

struct PackageFormView: View {
    enum Mode {
        case add
        case edit(UnityPackage)
    }

    @EnvironmentObject var store: PackageStore
    @Environment(\.dismiss) var dismiss

    let mode: Mode

    @State private var name: String = ""
    @State private var fileName: String = ""
    @State private var filePath: String = ""
    @State private var folder: String = ""
    @State private var url: String = ""
    @State private var notes: String = ""
    @State private var additionalPaths: [String] = []

    // フォルダ追加
    @State private var showAddFolder = false
    @State private var newFolderName = ""

    // 追加ファイル・フォルダ
    @State private var showAdditional = false

    // ページタイトル・サムネイル取得
    @State private var pageTitle: String? = nil
    @State private var thumbnailURL: String? = nil
    @State private var isFetchingTitle = false
    @State private var lastFetchedURL: String = ""

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──
            HStack {
                Text(isEdit ? "パッケージを編集" : "パッケージを追加")
                    .font(.headline)
                Spacer()
                Button("キャンセル") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isEdit ? "更新" : "追加") { commit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
                    .buttonStyle(.borderedProminent)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // パッケージ名
                    fieldLabel("パッケージ名 *")
                    TextField("例: DOTween Pro", text: $name)
                        .textFieldStyle(.roundedBorder)

                    // unitypackageファイル
                    fieldLabel("unitypackageファイル")
                    HStack {
                        TextField("example.unitypackage", text: $fileName)
                            .textFieldStyle(.roundedBorder)
                        Button("選択...") { pickFile() }
                            .buttonStyle(.bordered)
                    }
                    if !filePath.isEmpty {
                        Text(filePath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }

                    // フォルダ
                    fieldLabel("フォルダ")
                    HStack {
                        Picker("", selection: $folder) {
                            ForEach(store.allFolders, id: \.self) { f in
                                Text(f).tag(f)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)

                        Button {
                            showAddFolder.toggle()
                            newFolderName = ""
                        } label: {
                            Image(systemName: showAddFolder ? "xmark" : "folder.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .help("新しいフォルダを追加")
                    }
                    if showAddFolder {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                                .foregroundStyle(Color.accentColor)
                            TextField("新しいフォルダ名", text: $newFolderName)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit { commitNewFolder() }
                            Button("作成") { commitNewFolder() }
                                .buttonStyle(.bordered)
                                .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(10)
                        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.accentColor.opacity(0.3))
                        )
                    }

                    // URL
                    fieldLabel("販売ページURL")
                    TextField("https://assetstore.unity.com/...", text: $url)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: url) { newURL in
                            if newURL != lastFetchedURL {
                                pageTitle = nil
                            }
                        }

                    // ページタイトル・サムネイル取得UI
                    HStack(spacing: 10) {
                        // サムネイルプレビュー
                        if let thumbURL = thumbnailURL, let url = URL(string: thumbURL) {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color(nsColor: .controlBackgroundColor)
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            if isFetchingTitle {
                                ProgressView().scaleEffect(0.7).frame(width: 14, height: 14)
                                Text("取得中...").font(.caption).foregroundStyle(.secondary)
                            } else if let title = pageTitle {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                                Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(2).truncationMode(.tail)
                                Button("再取得") { fetchPageTitle() }.font(.caption).buttonStyle(.plain).foregroundStyle(Color.accentColor)
                            } else if !url.isEmpty {
                                Button {
                                    fetchPageTitle()
                                } label: {
                                    Label("ページタイトル・サムネイルを取得", systemImage: "arrow.clockwise")
                                }
                                .font(.caption)
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .frame(minHeight: 20)

                    // 備考
                    fieldLabel("備考")
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .font(.body)
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color(nsColor: .separatorColor))
                        )

                    Divider()

                    // 追加ファイル・フォルダ（トグル）
                    Toggle(isOn: $showAdditional) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("追加ファイル・フォルダも一緒にコピー")
                                .font(.callout)
                                .fontWeight(.medium)
                            Text("アバターデータなど、unitypackage以外のアセットがある場合に使用")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if showAdditional {
                        AdditionalPathsView(paths: $additionalPaths)
                    }

                    if !filePath.isEmpty || !additionalPaths.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle").foregroundStyle(Color.accentColor)
                            Text("追加時にすべてのファイル・フォルダが整理先へコピーされます")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 540, height: 620)
        .onAppear { loadInitial() }
    }

    // MARK: - Helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
    }

    private func loadInitial() {
        switch mode {
        case .add:
            folder = store.allFolders.first ?? "アバター"
        case .edit(let pkg):
            name = pkg.name
            fileName = pkg.fileName
            filePath = pkg.filePath
            folder = pkg.folder
            url = pkg.url
            notes = pkg.notes
            additionalPaths = pkg.additionalPaths
            showAdditional = !pkg.additionalPaths.isEmpty
            pageTitle = pkg.pageTitle
            thumbnailURL = pkg.thumbnailURL
            lastFetchedURL = pkg.url
        }
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true
        panel.message = ".unitypackageファイルを選択してください"
        panel.prompt = "選択"
        guard panel.runModal() == .OK, let pickedURL = panel.url else { return }
        if pickedURL.pathExtension.lowercased() != "unitypackage" {
            let alert = NSAlert()
            alert.messageText = ".unitypackageファイルではありません"
            alert.informativeText = "ファイルの拡張子が .unitypackage ではありませんが、登録しますか？"
            alert.addButton(withTitle: "登録する")
            alert.addButton(withTitle: "キャンセル")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        filePath = pickedURL.path
        fileName = pickedURL.lastPathComponent
    }

    private func commitNewFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        store.addFolder(name)
        folder = name
        newFolderName = ""
        showAddFolder = false
    }

    private func fetchPageTitle() {
        guard !url.isEmpty, let reqURL = URL(string: url) else { return }
        isFetchingTitle = true
        pageTitle = nil
        thumbnailURL = nil
        lastFetchedURL = url

        var request = URLRequest(url: reqURL, timeoutInterval: 10)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            DispatchQueue.main.async {
                self.isFetchingTitle = false
                guard let data = data,
                      let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                    return
                }

                // <title> を抽出
                if let range = html.range(of: #"(?i)<title[^>]*>(.*?)</title>"#, options: .regularExpression) {
                    var title = String(html[range])
                    title = title.replacingOccurrences(of: #"(?i)<title[^>]*>"#, with: "", options: .regularExpression)
                    title = title.replacingOccurrences(of: #"(?i)</title>"#, with: "", options: .regularExpression)
                    title = title.replacingOccurrences(of: "&amp;", with: "&")
                    title = title.replacingOccurrences(of: "&lt;", with: "<")
                    title = title.replacingOccurrences(of: "&gt;", with: ">")
                    title = title.replacingOccurrences(of: "&quot;", with: "\"")
                    title = title.replacingOccurrences(of: "&#39;", with: "'")
                    title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.pageTitle = title.isEmpty ? nil : title
                }

                // og:image を抽出
                let ogPatterns = [
                    #"<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']"#,
                    #"<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']"#
                ]
                for pattern in ogPatterns {
                    if let range = html.range(of: pattern, options: .regularExpression) {
                        let tag = String(html[range])
                        if let contentRange = tag.range(of: #"content=["']([^"']+)["']"#, options: .regularExpression) {
                            var imgURL = String(tag[contentRange])
                            imgURL = imgURL.replacingOccurrences(of: #"content=["']"#, with: "", options: .regularExpression)
                            imgURL = imgURL.replacingOccurrences(of: #"["']$"#, with: "", options: .regularExpression)
                            imgURL = imgURL.trimmingCharacters(in: .whitespacesAndNewlines)
                            // 相対パスなら絶対URLに変換
                            if imgURL.hasPrefix("//") {
                                imgURL = "https:" + imgURL
                            } else if imgURL.hasPrefix("/"), let base = URL(string: self.url) {
                                imgURL = base.scheme.map { $0 + "://" + (base.host ?? "") + imgURL } ?? imgURL
                            }
                            if !imgURL.isEmpty { self.thumbnailURL = imgURL; break }
                        }
                    }
                }
            }
        }.resume()
    }

    private func commit() {
        switch mode {
        case .add:
            let pkg = UnityPackage(
                name: name.trimmingCharacters(in: .whitespaces),
                fileName: fileName,
                filePath: filePath,
                folder: folder,
                url: url,
                notes: notes,
                additionalPaths: showAdditional ? additionalPaths.filter { !$0.isEmpty } : [],
                pageTitle: pageTitle,
                thumbnailURL: thumbnailURL
            )
            store.add(pkg)
        case .edit(let original):
            var pkg = original
            pkg.name = name.trimmingCharacters(in: .whitespaces)
            pkg.fileName = fileName
            pkg.filePath = filePath
            pkg.folder = folder
            pkg.url = url
            pkg.notes = notes
            pkg.additionalPaths = showAdditional ? additionalPaths.filter { !$0.isEmpty } : []
            pkg.pageTitle = pageTitle
            pkg.thumbnailURL = thumbnailURL
            store.update(pkg)
        }
        dismiss()
    }
}

// MARK: - 追加ファイル・フォルダ選択UI

struct AdditionalPathsView: View {
    @Binding var paths: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !paths.isEmpty {
                VStack(spacing: 4) {
                    ForEach(Array(paths.enumerated()), id: \.offset) { index, path in
                        HStack(spacing: 8) {
                            Image(systemName: isDirectory(path) ? "folder.fill" : "doc.fill")
                                .foregroundStyle(isDirectory(path) ? .yellow : Color.accentColor)
                                .frame(width: 16)
                            Text(URL(fileURLWithPath: path).lastPathComponent)
                                .font(.callout)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(path)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.head)
                                .frame(maxWidth: 160)
                            Button {
                                paths.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    pickItems()
                } label: {
                    Label("ファイル・フォルダを追加...", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)

                if !paths.isEmpty {
                    Button(role: .destructive) {
                        paths.removeAll()
                    } label: {
                        Label("すべて削除", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(nsColor: .separatorColor))
        )
    }

    private func isDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return isDir.boolValue
    }

    private func pickItems() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "一緒にコピーするファイル・フォルダを選択（複数選択可）"
        panel.prompt = "追加"
        guard panel.runModal() == .OK else { return }
        let newPaths = panel.urls.map { $0.path }.filter { !paths.contains($0) }
        paths.append(contentsOf: newPaths)
    }
}
