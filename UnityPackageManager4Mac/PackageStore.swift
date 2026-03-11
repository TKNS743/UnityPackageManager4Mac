import Foundation
import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor
class PackageStore: ObservableObject {
    @Published var packages: [UnityPackage] = []
    @Published var settings: AppSettings = .default
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var needsOutputDirectorySetup: Bool = false
    @Published var missingPackages: [UUID] = []
    @Published var integrityIssues: [IntegrityIssue] = []
    @Published var showIntegrityDialog: Bool = false

    private let packagesURL: URL
    private let settingsURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("UnityPackageManager")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        packagesURL = dir.appendingPathComponent("packages.json")
        settingsURL = dir.appendingPathComponent("settings.json")
        load()
    }

    // MARK: - Persistence

    func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: packagesURL),
           let loaded = try? decoder.decode([UnityPackage].self, from: data) {
            packages = loaded
        }
        if let data = try? Data(contentsOf: settingsURL),
           let loaded = try? decoder.decode(AppSettings.self, from: data) {
            settings = loaded
        }
        if !settings.hasLaunched || settings.outputDirectory.isEmpty {
            needsOutputDirectorySetup = true
        }
        checkMissingFiles()
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(packages) { try? data.write(to: packagesURL) }
        if let data = try? encoder.encode(settings) { try? data.write(to: settingsURL) }
    }

    // MARK: - First Launch Setup

    func runFirstLaunchSetup() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "ここを使う"
        panel.message = "unitypackageファイルの整理先フォルダを選択してください"
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        if panel.runModal() == .OK, let url = panel.url {
            settings.outputDirectory = url.path
        } else {
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            settings.outputDirectory = downloads.appendingPathComponent("UnityPackages").path
        }
        settings.hasLaunched = true
        needsOutputDirectorySetup = false
        save()
    }

    // MARK: - CRUD

    func add(_ package: UnityPackage) {
        // 前提チェック
        if settings.outputDirectory.isEmpty {
            showError("整理先フォルダが未設定です。設定から保存先を選んでください。")
            return
        }
        if package.filePath.isEmpty {
            // メインファイル未選択の場合でも、追加ファイルのみで登録したいケースはあるが
            // ここでは明示的にエラーを出して分かりやすくする
            // もし許容したい場合はこのチェックを外してください
            showError("ファイルが選択されていません")
            return
        }

        var pkg = package
        if !pkg.filePath.isEmpty {
            if let newPath = copyToDestination(pkg) {
                pkg.filePath = newPath
                pkg.fileName = URL(fileURLWithPath: newPath).lastPathComponent
            } else {
                showError("「\(pkg.name)」のファイルコピーに失敗しました。選択したファイルの存在と、整理先フォルダの設定を確認してください。")
                return
            }
        }
        packages.append(pkg)
        save()
        showSuccess("「\(pkg.name)」を追加しました")
    }

    func update(_ package: UnityPackage) {
        guard let idx = packages.firstIndex(where: { $0.id == package.id }) else { return }
        let old = packages[idx]
        var pkg = package

        let needsReorganize = !old.filePath.isEmpty &&
            (old.folder != pkg.folder || old.name != pkg.name)

        if needsReorganize {
            let fm = FileManager.default
            let oldDir = packageDirectory(old)   // 旧ディレクトリ（old の folder/name で確定）
            let newDir = packageDirectory(pkg)   // 新ディレクトリ（pkg の folder/name で確定）

            guard let oldDir = oldDir, let newDir = newDir else { return }

            do {
                try fm.createDirectory(at: newDir, withIntermediateDirectories: true)
            } catch {
                showError("フォルダの作成に失敗: \(error.localizedDescription)")
                return
            }

            // ① メインファイルを旧ディレクトリから新ディレクトリへコピー（なければフォールバック）
            let mainFileName = URL(fileURLWithPath: old.filePath).lastPathComponent
            let srcMain = oldDir.appendingPathComponent(mainFileName)
            let dstMain = newDir.appendingPathComponent(mainFileName)
            var mainCopied = false
            if fm.fileExists(atPath: srcMain.path) {
                do {
                    if fm.fileExists(atPath: dstMain.path) { try fm.removeItem(at: dstMain) }
                    try fm.copyItem(at: srcMain, to: dstMain)
                    pkg.filePath = dstMain.path
                    pkg.fileName = mainFileName
                    mainCopied = true
                } catch {
                    showError("ファイルのコピーに失敗: \(error.localizedDescription)")
                    return
                }
            } else {
                // フォールバック: 実ファイルパスからコピー（old.filePath または pkg.filePath）
                let candidatePaths = [old.filePath, pkg.filePath].filter { !$0.isEmpty }
                if let existingSrcPath = candidatePaths.first(where: { fm.fileExists(atPath: $0) }) {
                    let srcFromOriginal = URL(fileURLWithPath: existingSrcPath)
                    let fallbackDst = newDir.appendingPathComponent(srcFromOriginal.lastPathComponent)
                    do {
                        if fm.fileExists(atPath: fallbackDst.path) { try fm.removeItem(at: fallbackDst) }
                        try fm.copyItem(at: srcFromOriginal, to: fallbackDst)
                        pkg.filePath = fallbackDst.path
                        pkg.fileName = srcFromOriginal.lastPathComponent
                        mainCopied = true
                    } catch {
                        showError("ファイルのコピーに失敗: \(error.localizedDescription)")
                        return
                    }
                }
            }

            // ② 追加ファイル・フォルダを旧ディレクトリから新ディレクトリへコピー
            // additionalPaths はソースパスだが、整理先にはファイル名で保存されている
            for addPath in pkg.additionalPaths {
                let itemName = URL(fileURLWithPath: addPath).lastPathComponent
                let srcItem = oldDir.appendingPathComponent(itemName)
                let dstItem = newDir.appendingPathComponent(itemName)

                if fm.fileExists(atPath: srcItem.path) {
                    do {
                        if fm.fileExists(atPath: dstItem.path) { try fm.removeItem(at: dstItem) }
                        try fm.copyItem(at: srcItem, to: dstItem)
                    } catch {
                        showError("追加ファイルの移動に失敗: \(itemName)")
                    }
                } else {
                    // フォールバック: 元の実ファイルパスからコピー
                    if fm.fileExists(atPath: addPath) {
                        let srcFromOriginal = URL(fileURLWithPath: addPath)
                        let fallbackDst = newDir.appendingPathComponent(srcFromOriginal.lastPathComponent)
                        do {
                            if fm.fileExists(atPath: fallbackDst.path) { try fm.removeItem(at: fallbackDst) }
                            try fm.copyItem(at: srcFromOriginal, to: fallbackDst)
                        } catch {
                            showError("追加ファイルの移動に失敗: \(srcFromOriginal.lastPathComponent)")
                        }
                    }
                }
            }

            // ③ コピー完了後に旧ディレクトリを削除
            if fm.fileExists(atPath: oldDir.path) {
                try? fm.removeItem(at: oldDir)
            }

            // ④ additionalPaths を新しい整理先パスに更新
            pkg.additionalPaths = pkg.additionalPaths.map { addPath in
                let itemName = URL(fileURLWithPath: addPath).lastPathComponent
                return newDir.appendingPathComponent(itemName).path
            }
        }

        packages[idx] = pkg
        save()
        NotificationCenter.default.post(name: .packageUpdated, object: pkg.folder)
        showSuccess("「\(pkg.name)」を更新しました")
    }

    func deleteFromList(_ package: UnityPackage) {
        packages.removeAll { $0.id == package.id }
        save()
        showSuccess("「\(package.name)」をリストから削除しました")
    }

    func deleteWithFile(_ package: UnityPackage) {
        if let pkgDir = packageDirectory(package) {
            let fm = FileManager.default
            if fm.fileExists(atPath: pkgDir.path) {
                do {
                    try fm.removeItem(at: pkgDir)
                } catch {
                    showError("フォルダの削除に失敗: \(error.localizedDescription)")
                    return
                }
            }
        }
        packages.removeAll { $0.id == package.id }
        save()
        showSuccess("「\(package.name)」をフォルダごと削除しました")
    }

    // MARK: - Reset

    func resetPackages() {
        packages = []
        missingPackages = []
        save()
        showSuccess("パッケージ一覧をリセットしました")
    }

    func resetAll() {
        packages = []
        settings = .default
        needsOutputDirectorySetup = true
        save()
        showSuccess("すべての設定をリセットしました")
    }

    /// 整理先フォルダを変更する。moveFiles=true の場合は既存ファイルも移動する
    func changeOutputDirectory(to newPath: String, moveFiles: Bool) {
        let fm = FileManager.default
        let oldPath = settings.outputDirectory
        guard !oldPath.isEmpty, oldPath != newPath else {
            settings.outputDirectory = newPath
            save()
            return
        }

        let oldRoot = URL(fileURLWithPath: oldPath)
        let newRoot = URL(fileURLWithPath: newPath)

        // moveFiles=false の場合はパスだけ変更して終了
        guard moveFiles else {
            settings.outputDirectory = newPath
            save()
            showSuccess("整理先フォルダを変更しました")
            return
        }

        // 既存ファイルを移動
        var movedCount = 0
        var failedCount = 0
        for i in 0..<packages.count {
            let pkg = packages[i]
            guard !pkg.filePath.isEmpty else { continue }

            // 旧ディレクトリ・新ディレクトリ
            let oldDir = oldRoot.appendingPathComponent(pkg.folder).appendingPathComponent(pkg.name)
            let newDir = newRoot.appendingPathComponent(pkg.folder).appendingPathComponent(pkg.name)

            guard fm.fileExists(atPath: oldDir.path) else { continue }

            do {
                try fm.createDirectory(at: newDir.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fm.fileExists(atPath: newDir.path) { try fm.removeItem(at: newDir) }
                try fm.moveItem(at: oldDir, to: newDir)

                // filePath を新しいパスに更新
                let fileName = URL(fileURLWithPath: pkg.filePath).lastPathComponent
                packages[i].filePath = newDir.appendingPathComponent(fileName).path

                // additionalPaths も新しい整理先に合わせて更新
                packages[i].additionalPaths = packages[i].additionalPaths.map { addPath in
                    let itemName = URL(fileURLWithPath: addPath).lastPathComponent
                    return newDir.appendingPathComponent(itemName).path
                }

                movedCount += 1
            } catch {
                failedCount += 1
            }
        }

        settings.outputDirectory = newPath
        save()

        if failedCount > 0 {
            showError("\(failedCount)件の移動に失敗しました（\(movedCount)件成功）")
        } else if movedCount > 0 {
            showSuccess("\(movedCount)件のパッケージを移動しました")
        } else {
            showSuccess("整理先フォルダを変更しました")
        }
    }

    func addFolder(_ name: String) {
        guard !settings.folders.contains(name) else { return }
        settings.folders.append(name)
        save()
    }

    /// フォルダを削除し、内包パッケージをリスト・ファイルごと削除する
    func deleteFolderWithPackages(_ name: String) {
        let fm = FileManager.default
        // 該当カテゴリのパッケージを全て削除
        let targets = packages.filter { $0.folder == name }
        for pkg in targets {
            if let pkgDir = packageDirectory(pkg), fm.fileExists(atPath: pkgDir.path) {
                try? fm.removeItem(at: pkgDir)
            }
        }
        // カテゴリフォルダ自体も削除（空なら）
        if !settings.outputDirectory.isEmpty {
            let categoryDir = URL(fileURLWithPath: settings.outputDirectory).appendingPathComponent(name)
            if fm.fileExists(atPath: categoryDir.path) {
                try? fm.removeItem(at: categoryDir)
            }
        }
        packages.removeAll { $0.folder == name }
        settings.folders.removeAll { $0 == name }
        save()
        showSuccess("「\(name)」と\(targets.count)件のパッケージを削除しました")
    }

    /// フォルダを削除し、内包パッケージを「未分類」へ移動する
    func deleteFolderKeepPackages(_ name: String) {
        let uncategorized = "未分類"
        // 「未分類」フォルダがなければ追加
        if !settings.folders.contains(uncategorized) {
            settings.folders.append(uncategorized)
        }
        // 該当カテゴリのパッケージを「未分類」へ移動（ファイルも移動）
        let targets = packages.indices.filter { packages[$0].folder == name }
        for i in targets {
            let old = packages[i]
            var pkg = old
            pkg.folder = uncategorized
            // ファイルを新しい場所へ移動
            let fm = FileManager.default
            let oldDir = packageDirectory(old)
            let newDir = packageDirectory(pkg)
            if let od = oldDir, let nd = newDir, fm.fileExists(atPath: od.path) {
                do {
                    try fm.createDirectory(at: nd.deletingLastPathComponent(), withIntermediateDirectories: true)
                    if fm.fileExists(atPath: nd.path) { try fm.removeItem(at: nd) }
                    try fm.moveItem(at: od, to: nd)
                    pkg.filePath = nd.appendingPathComponent(URL(fileURLWithPath: old.filePath).lastPathComponent).path
                } catch {
                    // 移動失敗時はパスだけ更新
                    pkg.filePath = nd.appendingPathComponent(URL(fileURLWithPath: old.filePath).lastPathComponent).path
                }
            }
            packages[i] = pkg
        }
        settings.folders.removeAll { $0 == name }
        save()
        showSuccess("「\(name)」を削除し、\(targets.count)件を未分類へ移動しました")
    }

    // MARK: - File Organization

    /// 整理先/カテゴリ/パッケージ名/ ディレクトリを返す
    func packageDirectory(_ package: UnityPackage) -> URL? {
        guard !settings.outputDirectory.isEmpty else { return nil }
        return URL(fileURLWithPath: settings.outputDirectory)
            .appendingPathComponent(package.folder)
            .appendingPathComponent(package.name)
    }

    /// ファイルを 整理先/カテゴリ/パッケージ名/ へコピーして新パスを返す（新規追加用）
    @discardableResult
    private func copyToDestination(_ package: UnityPackage) -> String? {
        let fm = FileManager.default
        let src = URL(fileURLWithPath: package.filePath)
        guard fm.fileExists(atPath: src.path), !settings.outputDirectory.isEmpty else { return nil }

        let destDir = URL(fileURLWithPath: settings.outputDirectory)
            .appendingPathComponent(package.folder)
            .appendingPathComponent(package.name)
        do {
            try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        } catch {
            showError("フォルダの作成に失敗: \(error.localizedDescription)")
            return nil
        }

        // メインファイルをコピー
        let dest = destDir.appendingPathComponent(src.lastPathComponent)
        if src.path != dest.path {
            do {
                if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
                try fm.copyItem(at: src, to: dest)
            } catch {
                showError("ファイルのコピーに失敗: \(error.localizedDescription)")
                return nil
            }
        }

        // 追加ファイル・フォルダをコピー
        for addPath in package.additionalPaths {
            let addSrc = URL(fileURLWithPath: addPath)
            guard fm.fileExists(atPath: addSrc.path) else { continue }
            let addDest = destDir.appendingPathComponent(addSrc.lastPathComponent)
            do {
                if fm.fileExists(atPath: addDest.path) { try fm.removeItem(at: addDest) }
                try fm.copyItem(at: addSrc, to: addDest)
            } catch {
                showError("追加ファイルのコピーに失敗: \(addSrc.lastPathComponent)")
            }
        }

        return dest.path
    }

    func revealInFinder(_ package: UnityPackage) {
        guard !package.filePath.isEmpty else { return }
        NSWorkspace.shared.selectFile(package.filePath, inFileViewerRootedAtPath: "")
    }

    func openOutputDirectory() {
        guard !settings.outputDirectory.isEmpty else { return }
        let url = URL(fileURLWithPath: settings.outputDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    // エクスポートとインポート機能はもう少し仕様の詰めが必要なのでオミット
    // func exportCSV() { ... }
    // func importCSV() { ... }

    // MARK: - Integrity Check

    func checkMissingFiles() {
        let fm = FileManager.default
        var issues: [IntegrityIssue] = []
        var missingIDs: [UUID] = []

        for pkg in packages {
            // メインファイルのチェック
            if !pkg.filePath.isEmpty && !fm.fileExists(atPath: pkg.filePath) {
                if !missingIDs.contains(pkg.id) { missingIDs.append(pkg.id) }
                issues.append(IntegrityIssue(kind: .missingFile, packageName: pkg.name, path: pkg.filePath))
            }
            // 追加ファイル・フォルダのコピー先チェック
            if let pkgDir = packageDirectory(pkg) {
                for addPath in pkg.additionalPaths {
                    let itemName = URL(fileURLWithPath: addPath).lastPathComponent
                    let destPath = pkgDir.appendingPathComponent(itemName).path
                    if !fm.fileExists(atPath: destPath) {
                        if !missingIDs.contains(pkg.id) { missingIDs.append(pkg.id) }
                        issues.append(IntegrityIssue(kind: .missingFile, packageName: "\(pkg.name)（追加: \(itemName)）", path: destPath))
                    }
                }
            }
        }
        missingPackages = missingIDs

        // 整理先にある未登録の .unitypackage
        if !settings.outputDirectory.isEmpty {
            var registeredPaths = Set(packages.map { $0.filePath })
            for pkg in packages {
                if let pkgDir = packageDirectory(pkg) {
                    for addPath in pkg.additionalPaths {
                        let itemName = URL(fileURLWithPath: addPath).lastPathComponent
                        registeredPaths.insert(pkgDir.appendingPathComponent(itemName).path)
                    }
                }
            }
            let outputURL = URL(fileURLWithPath: settings.outputDirectory)
            if let enumerator = fm.enumerator(at: outputURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    guard fileURL.pathExtension.lowercased() == "unitypackage" else { continue }
                    if !registeredPaths.contains(fileURL.path) {
                        issues.append(IntegrityIssue(kind: .unregistered, packageName: fileURL.deletingPathExtension().lastPathComponent, path: fileURL.path))
                    }
                }
            }
        }

        integrityIssues = issues
        if !issues.isEmpty { showIntegrityDialog = true }
    }

    func isMissing(_ package: UnityPackage) -> Bool {
        missingPackages.contains(package.id)
    }

    // MARK: - Helpers

    var allFolders: [String] {
        let used = Set(packages.map { $0.folder })
        let extra = used.filter { !settings.folders.contains($0) }
        return settings.folders + extra.sorted()
    }

    private func showError(_ msg: String) {
        errorMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { self.errorMessage = nil }
    }

    private func showSuccess(_ msg: String) {
        successMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { self.successMessage = nil }
    }
}
