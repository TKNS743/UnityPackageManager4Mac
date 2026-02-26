import SwiftUI
import AppKit

// ツールバーのラベル表示をデフォルトで有効にするヘルパー
struct ToolbarLabelModifier: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.toolbar?.displayMode = .iconAndLabel
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct ContentView: View {
    @EnvironmentObject var store: PackageStore
    @State private var selectedID: UUID?
    @State private var folderFilter: String = "ALL"
    @State private var search: String = ""
    @State private var showAddSheet = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    private let addNotif    = NotificationCenter.default.publisher(for: .addPackage)
    // エクスポートとインポート機能はもう少し仕様の詰めが必要なのでオミット
    /*
    private let exportNotif = NotificationCenter.default.publisher(for: .exportCSV)
    private let importNotif = NotificationCenter.default.publisher(for: .importCSV)
     */

    var filtered: [UnityPackage] {
        store.packages.filter { pkg in
            let matchFolder = folderFilter == "ALL" || pkg.folder == folderFilter
            let q = search.lowercased()
            let matchSearch = q.isEmpty ||
                pkg.name.lowercased().contains(q) ||
                pkg.fileName.lowercased().contains(q) ||
                pkg.notes.lowercased().contains(q) ||
                pkg.folder.lowercased().contains(q)
            return matchFolder && matchSearch
        }
        .sorted { $0.name < $1.name }
    }

    var selectedPackage: UnityPackage? {
        guard let id = selectedID else { return nil }
        return store.packages.first { $0.id == id }
    }

    var body: some View {
        NavigationSplitView() {
            SidebarView(folderFilter: $folderFilter)
        } content: {
            PackageListView(
                packages: filtered,
                selectedID: $selectedID,
                search: $search
            )
            .navigationTitle("パッケージ")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("追加", systemImage: "plus")
                    }
                    .help("パッケージを追加 (⌘N)")
                }
                ToolbarItemGroup(placement: .secondaryAction) {
                    // エクスポートとインポート機能はもう少し仕様の詰めが必要なのでオミット
                    /*
                    Button { store.exportCSV() } label: {
                        Label("CSVエクスポート", systemImage: "square.and.arrow.up")
                    }
                    Button { store.importCSV() } label: {
                        Label("CSVインポート", systemImage: "square.and.arrow.down")
                    }
                     */
                }
            }
        } detail: {
            if let pkg = selectedPackage {
                PackageDetailView(package: pkg, selectedID: $selectedID)
            } else {
                EmptyDetailView()
            }
        }
        .sheet(isPresented: $showAddSheet) {
            PackageFormView(mode: .add)
        }
        .overlay(alignment: .bottom) {
            ToastView()
        }
        .onReceive(addNotif)    { _ in showAddSheet = true }
        // エクスポートとインポート機能はもう少し仕様の詰めが必要なのでオミット
        /*
        .onReceive(exportNotif) { _ in store.exportCSV() }
        .onReceive(importNotif) { _ in store.importCSV() }
        */
         .background(ToolbarLabelModifier())
    }
}

// MARK: - Empty State

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "shippingbox")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(.quaternary)
            Text("パッケージを選択してください")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("左のリストからパッケージを選ぶと\n詳細が表示されます")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Toast

struct ToastView: View {
    @EnvironmentObject var store: PackageStore

    var message: String? { store.errorMessage ?? store.successMessage }
    var isError: Bool { store.errorMessage != nil }

    var body: some View {
        if let msg = message {
            HStack(spacing: 8) {
                Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(isError ? .red : .green)
                Text(msg)
                    .font(.callout)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 8, y: 4)
            .padding(.bottom, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4), value: message)
        }
    }
}
