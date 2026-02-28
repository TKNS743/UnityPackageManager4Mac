import Foundation

// MARK: - UnityPackage Model

struct UnityPackage: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var fileName: String
    var filePath: String          // 整理先の絶対パス
    var folder: String
    var url: String
    var notes: String
    var addedAt: Date = Date()
    var fileSize: Int64?
    var additionalPaths: [String] = []  // 一緒にコピーする追加ファイル・フォルダ（ソースパス）
    var pageTitle: String? = nil

    static func == (lhs: UnityPackage, rhs: UnityPackage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - App Settings

struct AppSettings: Codable {
    var folders: [String]
    var outputDirectory: String
    var hasLaunched: Bool

    static var `default`: AppSettings {
        AppSettings(
            folders: ["アバター"],
            outputDirectory: "",
            hasLaunched: false
        )
    }
}

// MARK: - IntegrityIssue

struct IntegrityIssue: Identifiable {
    enum Kind {
        case missingFile    // 登録済みだがファイルが存在しない
        case unregistered   // 整理先にあるが未登録
    }
    let id = UUID()
    let kind: Kind
    let packageName: String
    let path: String
}
