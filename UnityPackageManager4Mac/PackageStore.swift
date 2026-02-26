import Foundation
import AppKit
import Combine
import UniformTypeIdentifiers

// MARK: - PackageStore

@MainActor
class PackageStore: ObservableObject {
    @Published var packages: [UnityPackage] = []
    @Published var settings: AppSettings = .default
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var needsOutputDirectorySetup: Bool = false  // 初回起動ダイアログ制御

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
        // 初回起動、または出力フォルダ未設定なら設定ダイアログを表示
        if !settings.hasLaunched || settings.outputDirectory.isEmpty {
            needsOutputDirectorySetup = true
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(packages) {
            try? data.write(to: packagesURL)
        }
        if let data = try? encoder.encode(settings) {
            try? data.write(to: settingsURL)
        }
    }

    // MARK: - First Launch Setup

    /// 初回起動時の出力フォルダ選択
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
            // キャンセルした場合はデフォルト（~/Downloads/UnityPackages）
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            settings.outputDirectory = downloads.appendingPathComponent("UnityPackages").path
        }
        settings.hasLaunched = true
        needsOutputDirectorySetup = false
        save()
    }

    // MARK: - CRUD

    func add(_ package: UnityPackage) {
        var pkg = package
        // 追加と同時に自動整理
        if !pkg.filePath.isEmpty {
            if let newPath = moveFile(pkg) {
                pkg.filePath = newPath
                pkg.fileName = URL(fileURLWithPath: newPath).lastPathComponent
            }
        }
        packages.append(pkg)
        save()
        showSuccess("「\(pkg.name)」を追加しました")
    }

    func update(_ package: UnityPackage) {
        if let idx = packages.firstIndex(where: { $0.id == package.id }) {
            packages[idx] = package
            save()
            showSuccess("「\(package.name)」を更新しました")
        }
    }

    /// リストからのみ削除（ファイルはそのまま）
    func deleteFromList(_ package: UnityPackage) {
        packages.removeAll { $0.id == package.id }
        save()
        showSuccess("「\(package.name)」をリストから削除しました")
    }

    /// リストから削除 + 整理先の「パッケージ名フォルダ」ごと削除
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

    /// パッケージ一覧のみ削除（設定は保持）
    func resetPackages() {
        packages = []
        save()
        showSuccess("パッケージ一覧をリセットしました")
    }

    /// パッケージ・設定をすべて初期化
    func resetAll() {
        packages = []
        settings = .default
        needsOutputDirectorySetup = true
        save()
        showSuccess("すべての設定をリセットしました")
    }

    func addFolder(_ name: String) {
        guard !settings.folders.contains(name) else { return }
        settings.folders.append(name)
        save()
    }

    func deleteFolder(_ name: String) {
        settings.folders.removeAll { $0 == name }
        save()
    }

    // MARK: - File Organization

    /// ファイルを outputDirectory/フォルダ名/パッケージ名/ へコピーして新パスを返す
    @discardableResult
    func moveFile(_ package: UnityPackage) -> String? {
        guard !package.filePath.isEmpty, !settings.outputDirectory.isEmpty else { return nil }
        let fm = FileManager.default
        let src = URL(fileURLWithPath: package.filePath)
        guard fm.fileExists(atPath: src.path) else { return nil }

        // 整理先/フォルダ名/パッケージ名/
        let destDir = URL(fileURLWithPath: settings.outputDirectory)
            .appendingPathComponent(package.folder)
            .appendingPathComponent(package.name)
        do {
            try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        } catch {
            showError("フォルダの作成に失敗: \(error.localizedDescription)")
            return nil
        }

        let dest = destDir.appendingPathComponent(src.lastPathComponent)
        if src.path != dest.path {
            do {
                if fm.fileExists(atPath: dest.path) {
                    try fm.removeItem(at: dest)
                }
                try fm.copyItem(at: src, to: dest)
            } catch {
                showError("ファイルのコピーに失敗: \(error.localizedDescription)")
                return nil
            }
        }

        // 追加ファイル・フォルダのコピー
        for additionalPath in package.additionalPaths {
            let addSrc = URL(fileURLWithPath: additionalPath)
            guard fm.fileExists(atPath: addSrc.path) else { continue }
            let addDest = destDir.appendingPathComponent(addSrc.lastPathComponent)
            do {
                if fm.fileExists(atPath: addDest.path) {
                    try fm.removeItem(at: addDest)
                }
                try fm.copyItem(at: addSrc, to: addDest)
            } catch {
                showError("追加ファイルのコピーに失敗: \(addSrc.lastPathComponent) - \(error.localizedDescription)")
            }
        }

        return dest.path
    }

    /// パッケージ名フォルダのパス（整理先/フォルダ名/パッケージ名/）
    func packageDirectory(_ package: UnityPackage) -> URL? {
        guard !settings.outputDirectory.isEmpty else { return nil }
        return URL(fileURLWithPath: settings.outputDirectory)
            .appendingPathComponent(package.folder)
            .appendingPathComponent(package.name)
    }

    /// Finder でファイルを表示
    func revealInFinder(_ package: UnityPackage) {
        guard !package.filePath.isEmpty else { return }
        NSWorkspace.shared.selectFile(package.filePath, inFileViewerRootedAtPath: "")
    }

    /// 出力ディレクトリを Finder で開く
    func openOutputDirectory() {
        guard !settings.outputDirectory.isEmpty else { return }
        let url = URL(fileURLWithPath: settings.outputDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    // エクスポートとインポート機能はもう少し仕様の詰めが必要なのでオミット
    /*
    // MARK: - CSV Export

    func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "unity-packages-\(dateString()).csv"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        var lines = [UnityPackage.csvHeader]
        lines += packages.map { $0.csvRow }
        let csv = lines.joined(separator: "\n")
        let withBOM = "\u{FEFF}" + csv

        do {
            try withBOM.write(to: url, atomically: true, encoding: .utf8)
            showSuccess("CSVをエクスポートしました")
        } catch {
            showError("エクスポート失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - CSV Import

    func importCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            var text = try String(contentsOf: url, encoding: .utf8)
            if text.hasPrefix("\u{FEFF}") { text = String(text.dropFirst()) }

            let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
            guard lines.count > 1 else {
                showError("CSVにデータがありません")
                return
            }

            var imported = 0
            for line in lines.dropFirst() {
                if var pkg = UnityPackage.from(csvRow: line) {
                    if !settings.folders.contains(pkg.folder) {
                        settings.folders.append(pkg.folder)
                    }
                    packages.append(pkg)
                    imported += 1
                }
            }
            save()
            showSuccess("\(imported)件インポートしました")
        } catch {
            showError("インポート失敗: \(error.localizedDescription)")
        }
    }
     */

    // MARK: - Helpers

    var allFolders: [String] {
        let used = Set(packages.map { $0.folder })
        let extra = used.filter { !settings.folders.contains($0) }
        return settings.folders + extra.sorted()
    }

    private func dateString() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
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
