import AppKit
import DesktopFileWidgetCore
import SwiftUI
import UniformTypeIdentifiers

struct ExplorerWidgetView: View {
    @ObservedObject var viewModel: ExplorerViewModel
    @ObservedObject private var sharedState: SharedExplorerState
    @Environment(\.colorScheme) private var colorScheme
    @State private var mouseNavigationMonitor: Any?

    init(viewModel: ExplorerViewModel) {
        self.viewModel = viewModel
        self.sharedState = viewModel.sharedState
    }

    var body: some View {
        let tokens = ThemeTokens.resolve(colorScheme)
        VStack(spacing: 8) {
            header(tokens: tokens)
            controls(tokens: tokens)
            fileList(tokens: tokens)
            footer(tokens: tokens)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(tokens.panel)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(tokens.panelStroke, lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tokens.panelInnerStroke, lineWidth: 1)
                        .padding(3)
                )
        )
        .preferredColorScheme(sharedState.theme.colorScheme)
        .alert("File operation failed", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
        .confirmationDialog(
            "Move to Trash?",
            isPresented: Binding(
                get: { !viewModel.pendingTrashURLs.isEmpty },
                set: { if !$0 { viewModel.pendingTrashURLs = [] } }
            ),
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) { viewModel.confirmTrash() }
            Button("Cancel", role: .cancel) { viewModel.pendingTrashURLs = [] }
        } message: {
            Text(trashConfirmationMessage)
        }
        .background(
            KeyEventReader(
                onKeyDown: { event in viewModel.handleKey(event) },
                onNavigateBack: { viewModel.goBack() },
                onNavigateForward: { viewModel.goForward() }
            )
            .frame(width: 0, height: 0)
        )
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            loadDroppedURLs(from: providers) { urls in
                viewModel.handleDroppedFileURLs(urls)
            }
            return true
        }
        .onAppear {
            mouseNavigationMonitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { event in
                switch event.buttonNumber {
                case 3:
                    viewModel.goBack()
                    return nil
                case 4:
                    viewModel.goForward()
                    return nil
                default:
                    return event
                }
            }
        }
        .onDisappear {
            if let mouseNavigationMonitor {
                NSEvent.removeMonitor(mouseNavigationMonitor)
                self.mouseNavigationMonitor = nil
            }
        }
    }

    private func header(tokens: ThemeTokens) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(tokens.headerGlow)
                    .frame(width: 24, height: 24)
                    .blur(radius: 6)
                Circle()
                    .fill(tokens.accent)
                    .frame(width: 9, height: 9)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Pocket Finder")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(tokens.text)
                Text(viewModel.currentFolder.path)
                    .font(rowFont(size: 12))
                    .foregroundStyle(tokens.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
            Picker("Theme", selection: $sharedState.theme) {
                ForEach(WidgetTheme.allCases) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 96)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tokens.headerStart, tokens.header, tokens.headerEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 5) {
                        Circle().fill(tokens.headerSpark.opacity(0.92)).frame(width: 7, height: 7)
                        Circle().fill(tokens.accent.opacity(0.78)).frame(width: 5, height: 5)
                        Circle().fill(Color.white.opacity(0.72)).frame(width: 3, height: 3)
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 118)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tokens.panelInnerStroke, lineWidth: 1)
                )
        )
    }

    private func controls(tokens: ThemeTokens) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Picker("Folder", selection: Binding(
                    get: { viewModel.currentFolder },
                    set: { viewModel.selectFolder($0) }
                )) {
                    ForEach(viewModel.folderChoices) { choice in
                        Text(choice.title).tag(choice.url)
                    }
                }
                .controlSize(.small)

                Button {
                    viewModel.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .help("Back")
                .disabled(!viewModel.canGoBack)
                .controlSize(.small)

                Button {
                    viewModel.goForward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .help("Forward")
                .disabled(!viewModel.canGoForward)
                .controlSize(.small)

                Button {
                    viewModel.navigateUp()
                } label: {
                    Image(systemName: "arrow.up")
                }
                .help("Parent folder")
                .controlSize(.small)

                Button {
                    viewModel.createFolder()
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .help("Create folder")
                .controlSize(.small)

                Button {
                    viewModel.load()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
                .controlSize(.small)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(tokens.secondaryText)
                TextField("Search visible files", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(rowFont())
                    .foregroundStyle(tokens.text)
                if !viewModel.searchText.isEmpty {
                    Button("Clear") { viewModel.searchText = "" }
                        .font(rowFont(size: 11))
                        .buttonStyle(.plain)
                        .foregroundStyle(tokens.accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(tokens.rowA)
                    .overlay(Capsule().stroke(tokens.panelStroke, lineWidth: 1))
            )
        }
    }

    private func fileList(tokens: ThemeTokens) -> some View {
        VStack(spacing: 0) {
            sortHeader(tokens: tokens)
            NativeFileTableView(
                items: viewModel.filteredItems,
                selectedURLs: viewModel.selectedURLs,
                tokens: tokens,
                onSelectionChange: { urls in viewModel.selectURLs(urls) },
                onOpen: { item, reveal in viewModel.activate(item, revealInFinder: reveal) },
                onMove: { items in viewModel.chooseMoveDestination(for: items) },
                onTrash: { items in viewModel.requestTrash(items) },
                onRename: { item in viewModel.beginRename(item) },
                onDrop: { urls, folder in viewModel.handleDroppedFileURLs(urls, into: folder) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tokens.panelStroke, lineWidth: 1)
        )
    }

    private func sortHeader(tokens: ThemeTokens) -> some View {
        HStack(spacing: 0) {
            sortButton("Name", key: .name, width: nil, tokens: tokens)
            sortButton("Date", key: .date, width: 92, tokens: tokens)
            sortButton("Type", key: .type, width: 80, tokens: tokens)
            sortButton("Size", key: .size, width: 58, tokens: tokens)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(tokens.rowB)
    }

    private func sortButton(_ title: String, key: SortKey, width: CGFloat?, tokens: ThemeTokens) -> some View {
        Button {
            viewModel.toggleSort(key)
        } label: {
            HStack(spacing: 3) {
                Text(title)
                if viewModel.sortKey == key {
                    Image(systemName: viewModel.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .frame(maxWidth: width == nil ? .infinity : width, alignment: .leading)
            .frame(width: width, alignment: .leading)
        }
        .buttonStyle(.plain)
        .font(rowFont(size: 12).weight(.semibold))
        .foregroundStyle(tokens.secondaryText)
    }

    private func footer(tokens: ThemeTokens) -> some View {
        HStack {
            Text(footerCount)
            Spacer()
            Text("⌘ click adds · Shift click ranges · Enter opens")
        }
        .font(rowFont(size: 12))
        .foregroundStyle(tokens.secondaryText)
    }

    private var footerCount: String {
        let total = viewModel.filteredItems.count
        let selected = viewModel.selectedURLs.count
        return selected > 0 ? "\(selected) selected · \(total) items" : "\(total) items"
    }

    private var trashConfirmationMessage: String {
        let count = viewModel.pendingTrashURLs.count
        if count == 1 {
            return "This only moves “\(viewModel.pendingTrashURLs[0].lastPathComponent)” to Trash. It will not be permanently deleted."
        }
        return "This only moves \(count) selected items to Trash. They will not be permanently deleted."
    }

    private func rowFont(size: CGFloat = 14) -> Font {
        if NSFont(name: "Roboto", size: size) != nil {
            return .custom("Roboto", size: size)
        }
        return .system(size: size, design: .rounded)
    }

    private func loadDroppedURLs(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
        let accumulator = DroppedURLAccumulator()
        let group = DispatchGroup()
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                if let data = item as? Data,
                   let string = String(data: data, encoding: .utf8),
                   let url = URL(string: string) {
                    accumulator.append(url)
                } else if let url = item as? URL {
                    accumulator.append(url)
                }
            }
        }
        group.notify(queue: .main) {
            completion(accumulator.urls)
        }
    }
}

private final class DroppedURLAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URL] = []

    var urls: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ url: URL) {
        lock.lock()
        storage.append(url)
        lock.unlock()
    }
}

private struct FileRowView: View {
    let item: FileItem
    let index: Int
    let isSelected: Bool
    let isEditing: Bool
    @Binding var editingName: String
    let tokens: ThemeTokens
    let rowFont: Font
    let onCommitRename: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 7) {
            Image(nsImage: icon(for: item.url))
                .resizable()
                .frame(width: 16, height: 16)
            if isEditing {
                TextField("Name", text: $editingName)
                    .textFieldStyle(.roundedBorder)
                    .font(rowFont)
                    .onSubmit(onCommitRename)
            } else {
            Text(item.name)
                    .font(rowFont)
                    .foregroundStyle(tokens.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 8)
            Text(formatDate(item.modifiedAt))
                .frame(width: 86, alignment: .leading)
                .foregroundStyle(tokens.secondaryText)
            Text(item.typeDescription)
                .frame(width: 74, alignment: .leading)
                .foregroundStyle(tokens.secondaryText)
                .lineLimit(1)
            Text(formatSize(item))
                .frame(width: 52, alignment: .trailing)
                .foregroundStyle(tokens.secondaryText)
        }
        .font(rowFont)
        .padding(.horizontal, 8)
        .frame(minHeight: 31)
        .background(background)
        .onHover { isHovering = $0 }
    }

    private var background: Color {
        if isSelected { return tokens.rowSelected }
        if isHovering { return tokens.rowHover }
        return index.isMultiple(of: 2) ? tokens.rowA : tokens.rowB
    }

    private func icon(for url: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatSize(_ item: FileItem) -> String {
        guard item.kind != .folder else { return "—" }
        return ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file)
    }
}
