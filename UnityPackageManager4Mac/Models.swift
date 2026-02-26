import Foundation

// MARK: - UnityPackage Model

struct UnityPackage: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var fileName: String
    var filePath: String
    var folder: String
    var url: String
    var notes: String
    var addedAt: Date = Date()
    var fileSize: Int64?
    var additionalPaths: [String] = []   // 一緒にコピーする追加ファイル・フォルダ
    var pageTitle: String? = nil            // 販売ページのタイトル（登録時に取得・保存）

    static func == (lhs: UnityPackage, rhs: UnityPackage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - App Settings

struct AppSettings: Codable {
    var folders: [String]
    var outputDirectory: String
    var hasLaunched: Bool       // 初回起動チェック用

    static var `default`: AppSettings {
        AppSettings(
            folders: ["アバター"],
            outputDirectory: "",   // 初回は空 → 起動時ダイアログで設定
            hasLaunched: false
        )
    }
}

// MARK: - CSV

extension UnityPackage {
    static let csvHeader = "名前,ファイル名,フォルダ,URL,備考,追加日,ファイルパス"

    var csvRow: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let fields = [name, fileName, folder, url, notes, formatter.string(from: addedAt), filePath]
        return fields.map { field in
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }.joined(separator: ",")
    }

    static func from(csvRow: String) -> UnityPackage? {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = csvRow.startIndex

        while i < csvRow.endIndex {
            let c = csvRow[i]
            if c == "\"" {
                let next = csvRow.index(after: i)
                if inQuotes && next < csvRow.endIndex && csvRow[next] == "\"" {
                    current.append("\"")
                    i = csvRow.index(after: next)
                    continue
                }
                inQuotes.toggle()
            } else if c == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(c)
            }
            i = csvRow.index(after: i)
        }
        fields.append(current)

        guard fields.count >= 3, !fields[0].isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var pkg = UnityPackage(
            name: fields[0],
            fileName: fields.count > 1 ? fields[1] : "",
            filePath: fields.count > 6 ? fields[6] : "",
            folder: fields.count > 2 ? fields[2] : "アバター",
            url: fields.count > 3 ? fields[3] : "",
            notes: fields.count > 4 ? fields[4] : ""
        )
        if fields.count > 5, let date = formatter.date(from: fields[5]) {
            pkg.addedAt = date
        }
        return pkg
    }
}
