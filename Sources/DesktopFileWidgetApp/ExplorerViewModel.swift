import AppKit
import Combine
import DesktopFileWidgetCore
import Foundation
import UniformTypeIdentifiers

struct FolderChoice: Identifiable, Hashable {
    let id: URL
    let title: String
    let url: URL
}

@MainActor
final class SharedExplorerState: ObservableObject {
    @Published var theme: WidgetTheme = .system
}

@MainActor
final class ExplorerViewModel: ObservableObject {
    @Published var currentFolder: URL
    @Published var items: [FileItem] = []
    @Published var searchText = ""
    @Published var sortKey: SortKey = .name
    @Published var sortAscending = true
    @Published var selectedURL: URL?
    @Published var selectedURLs: Set<URL> = []
    @Published var editingURL: URL?
    @Published var editingName = ""
    @Published var errorMessage: String?
    @Published var pendingTrashURLs: [URL] = []
    @Published var isLoading = false
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false

    let sharedState: SharedExplorerState

    private let service: FileSystemService
    private var backStack: [URL] = []
    private var forwardStack: [URL] = []
    private var selectionAnchorURL: URL?

    init(sharedState: SharedExplorerState, service: FileSystemService = FileSystemService()) {
        self.sharedState = sharedState
        self.service = service
        self.currentFolder = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        load()
    }

    var folderChoices: [FolderChoice] {
        var choices: [FolderChoice] = []
        appendStandard(.desktopDirectory, title: "Desktop", to: &choices)
        appendStandard(.downloadsDirectory, title: "Downloads", to: &choices)
        appendStandard(.documentDirectory, title: "Documents", to: &choices)
        choices.append(FolderChoice(title: "Home", url: FileManager.default.homeDirectoryForCurrentUser))

        let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeIsInternalKey, .volumeIsBrowsableKey],
            options: [.skipHiddenVolumes]
        ) ?? []
        for volume in volumes {
            guard volume.path != "/" else { continue }
            choices.append(FolderChoice(title: volume.lastPathComponent, url: volume))
        }
        var seen = Set<URL>()
        return choices.filter { choice in
            seen.insert(choice.url).inserted
        }
    }

    var filteredItems: [FileItem] {
        let filtered = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? items
            : items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return FileSorter.sorted(filtered, by: sortKey, ascending: sortAscending)
    }

    func selectFolder(_ folder: URL) {
        navigate(to: folder)
    }

    func goBack() {
        guard let destination = backStack.popLast() else { return }
        forwardStack.append(currentFolder)
        setCurrentFolder(destination)
        updateNavigationAvailability()
    }

    func goForward() {
        guard let destination = forwardStack.popLast() else { return }
        backStack.append(currentFolder)
        setCurrentFolder(destination)
        updateNavigationAvailability()
    }

    func navigate(to folder: URL) {
        guard folder != currentFolder else { return }
        backStack.append(currentFolder)
        forwardStack.removeAll()
        setCurrentFolder(folder)
        updateNavigationAvailability()
    }

    private func setCurrentFolder(_ folder: URL) {
        currentFolder = folder
        clearSelection()
        load()
    }

    func load() {
        isLoading = true
        do {
            items = try service.listItems(in: currentFolder)
        } catch {
            items = []
            errorMessage = userMessage(for: error)
        }
        isLoading = false
    }

    func navigateUp() {
        let parent = currentFolder.deletingLastPathComponent()
        guard parent != currentFolder else { return }
        navigate(to: parent)
    }

    func activate(_ item: FileItem, revealInFinder: Bool = false) {
        selectOnly(item.url)
        if revealInFinder {
            service.revealInFinder(item.url)
            return
        }
        if item.kind == .folder {
            navigate(to: item.url)
        } else {
            service.openWithDefaultApp(item.url)
        }
    }

    func select(_ item: FileItem, modifiers: NSEvent.ModifierFlags = []) {
        if modifiers.contains(.shift), let anchor = selectionAnchorURL {
            selectRange(from: anchor, to: item.url)
        } else if modifiers.contains(.command) {
            if selectedURLs.contains(item.url) {
                selectedURLs.remove(item.url)
                selectedURL = selectedURLs.contains(selectedURL ?? URL(fileURLWithPath: "")) ? selectedURL : selectedURLs.first
            } else {
                selectedURLs.insert(item.url)
                selectedURL = item.url
            }
            selectionAnchorURL = item.url
        } else {
            selectOnly(item.url)
        }
    }

    func selectedItems(containing item: FileItem) -> [FileItem] {
        if selectedURLs.contains(item.url) {
            return filteredItems.filter { selectedURLs.contains($0.url) }
        }
        return [item]
    }

    func selectURLs(_ urls: Set<URL>) {
        selectedURLs = urls
        selectedURL = filteredItems.first(where: { urls.contains($0.url) })?.url
        selectionAnchorURL = selectedURL
    }

    func beginRename(_ item: FileItem) {
        editingURL = item.url
        editingName = item.name
    }

    func commitRename() {
        guard let editingURL else { return }
        do {
            _ = try service.renameItem(at: editingURL, to: editingName)
            self.editingURL = nil
            editingName = ""
            load()
        } catch {
            errorMessage = userMessage(for: error)
        }
    }

    func cancelRename() {
        editingURL = nil
        editingName = ""
    }

    func createFolder() {
        do {
            var candidate = "New Folder"
            var index = 2
            while FileManager.default.fileExists(atPath: currentFolder.appendingPathComponent(candidate).path) {
                candidate = "New Folder \(index)"
                index += 1
            }
            _ = try service.createFolder(named: candidate, in: currentFolder)
            load()
        } catch {
            errorMessage = userMessage(for: error)
        }
    }

    func chooseMoveDestination(for items: [FileItem]) {
        guard !items.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.title = items.count == 1 ? "Move \(items[0].name)" : "Move \(items.count) items"
        panel.message = "Choose a folder. Existing files will not be overwritten."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = currentFolder
        if panel.runModal() == .OK, let folder = panel.url {
            move(items.map(\.url), toFolder: folder)
        }
    }

    func move(_ source: URL, toFolder folder: URL) {
        move([source], toFolder: folder)
    }

    func move(_ sources: [URL], toFolder folder: URL) {
        do {
            for source in sources {
                _ = try service.moveItem(at: source, toFolder: folder)
            }
            clearSelection()
            load()
        } catch {
            errorMessage = userMessage(for: error)
        }
    }

    func requestTrash(_ items: [FileItem]) {
        pendingTrashURLs = items.map(\.url)
    }

    func confirmTrash() {
        guard !pendingTrashURLs.isEmpty else { return }
        do {
            for url in pendingTrashURLs {
                try service.trashItem(at: url)
            }
            pendingTrashURLs = []
            clearSelection()
            load()
        } catch {
            errorMessage = userMessage(for: error)
        }
    }

    func handleDroppedFileURLs(_ urls: [URL], into folder: URL? = nil) {
        let destination = folder ?? currentFolder
        for url in urls {
            move(url, toFolder: destination)
        }
    }

    func handleKey(_ event: NSEvent) {
        guard let selectedItem = items.first(where: { $0.url == selectedURL }) else {
            if event.keyCode == 53 { searchText = "" }
            return
        }
        switch event.keyCode {
        case 36:
            activate(selectedItem, revealInFinder: event.modifierFlags.contains(.command))
        case 53:
            if editingURL != nil {
                cancelRename()
            } else {
                searchText = ""
            }
        case 125, 126:
            moveSelection(delta: event.keyCode == 125 ? 1 : -1)
        default:
            break
        }
    }

    func toggleSort(_ key: SortKey) {
        if sortKey == key {
            sortAscending.toggle()
        } else {
            sortKey = key
            sortAscending = true
        }
    }

    private func moveSelection(delta: Int) {
        let visible = filteredItems
        guard !visible.isEmpty else { return }
        let currentIndex = selectedURL.flatMap { selected in visible.firstIndex(where: { $0.url == selected }) } ?? 0
        let newIndex = min(max(currentIndex + delta, 0), visible.count - 1)
        selectOnly(visible[newIndex].url)
    }

    private func clearSelection() {
        selectedURL = nil
        selectedURLs = []
        selectionAnchorURL = nil
    }

    private func selectOnly(_ url: URL) {
        selectedURL = url
        selectedURLs = [url]
        selectionAnchorURL = url
    }

    private func selectRange(from anchor: URL, to target: URL) {
        let visible = filteredItems
        guard
            let anchorIndex = visible.firstIndex(where: { $0.url == anchor }),
            let targetIndex = visible.firstIndex(where: { $0.url == target })
        else {
            selectOnly(target)
            return
        }

        let range = min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)
        selectedURLs = Set(range.map { visible[$0].url })
        selectedURL = target
    }

    private func updateNavigationAvailability() {
        canGoBack = !backStack.isEmpty
        canGoForward = !forwardStack.isEmpty
    }

    private func appendStandard(_ directory: FileManager.SearchPathDirectory, title: String, to choices: inout [FolderChoice]) {
        guard let url = FileManager.default.urls(for: directory, in: .userDomainMask).first else { return }
        choices.append(FolderChoice(title: title, url: url))
    }

    private func userMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileReadNoPermissionError {
            return """
            macOS blocked Pocket Finder from reading “\(currentFolder.lastPathComponent)”.

            Open System Settings > Privacy & Security > Files and Folders and allow Pocket Finder to access Desktop, Documents, and Downloads. If it is not listed there, add Pocket Finder under Full Disk Access, then relaunch the app.
            """
        }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

private extension FolderChoice {
    init(title: String, url: URL) {
        self.id = url
        self.title = title
        self.url = url
    }
}
