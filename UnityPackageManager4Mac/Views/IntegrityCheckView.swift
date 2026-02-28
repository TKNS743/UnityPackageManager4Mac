import SwiftUI

struct IntegrityCheckView: View {
    @EnvironmentObject var store: PackageStore
    @Environment(\.dismiss) var dismiss

    var missingFiles: [IntegrityIssue] {
        store.integrityIssues.filter { $0.kind == .missingFile }
    }
    var unregistered: [IntegrityIssue] {
        store.integrityIssues.filter { $0.kind == .unregistered }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("整合性チェックの結果")
                        .font(.headline)
                    Text("整理先フォルダとの間に \(store.integrityIssues.count) 件の差分が見つかりました")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // ① 登録済みだがファイルが存在しない
                    if !missingFiles.isEmpty {
                        issueSection(
                            title: "ファイルが見つからない（\(missingFiles.count) 件）",
                            subtitle: "登録済みですが、整理先にファイルが存在しません",
                            icon: "doc.fill.badge.ellipsis",
                            iconColor: .red,
                            issues: missingFiles
                        )
                    }

                    // ② 整理先にあるが未登録
                    if !unregistered.isEmpty {
                        issueSection(
                            title: "未登録のファイル（\(unregistered.count) 件）",
                            subtitle: "整理先フォルダにありますが、リストに登録されていません",
                            icon: "shippingbox.fill",
                            iconColor: .blue,
                            issues: unregistered
                        )
                    }
                }
                .padding(20)
            }

            Divider()

            // ── Footer ──
            HStack {
                Button {
                    // 再チェック
                    store.checkMissingFiles()
                    if store.integrityIssues.isEmpty { dismiss() }
                } label: {
                    Label("再チェック", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("閉じる") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .frame(width: 560, height: 480)
    }

    @ViewBuilder
    private func issueSection(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        issues: [IntegrityIssue]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.callout).fontWeight(.semibold)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 4) {
                ForEach(issues) { issue in
                    HStack(spacing: 8) {
                        Text(issue.packageName)
                            .font(.callout)
                            .lineLimit(1)
                        Spacer()
                        Text(issue.path)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.head)
                            .frame(maxWidth: 240)
                        Button {
                            NSWorkspace.shared.selectFile(issue.path, inFileViewerRootedAtPath: "")
                        } label: {
                            Image(systemName: "folder")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                        .help("Finderで表示")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
}
