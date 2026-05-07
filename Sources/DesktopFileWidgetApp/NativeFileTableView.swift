import AppKit
import DesktopFileWidgetCore
import SwiftUI

struct NativeFileTableView: NSViewRepresentable {
    let items: [FileItem]
    let selectedURLs: Set<URL>
    let tokens: ThemeTokens
    let onSelectionChange: (Set<URL>) -> Void
    let onOpen: (FileItem, Bool) -> Void
    let onMove: ([FileItem]) -> Void
    let onTrash: ([FileItem]) -> Void
    let onRename: (FileItem) -> Void
    let onDrop: ([URL], URL?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let tableView = FileTableView()
        tableView.headerView = nil
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.allowsMultipleSelection = true
        tableView.allowsEmptySelection = true
        tableView.rowHeight = 31
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.doubleAction = #selector(Coordinator.doubleClick(_:))
        tableView.target = context.coordinator
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.selectionDelegate = context.coordinator
        tableView.menuProvider = { row in
            context.coordinator.menu(for: row)
        }
        tableView.registerForDraggedTypes([.fileURL])
        tableView.setDraggingSourceOperationMask([.move, .delete], forLocal: false)

        addColumn("name", width: 420, to: tableView)
        addColumn("date", width: 112, to: tableView)
        addColumn("type", width: 94, to: tableView)
        addColumn("size", width: 72, to: tableView)

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = tableView
        context.coordinator.tableView = tableView
        context.coordinator.parent = self
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let tableView = scrollView.documentView as? NSTableView else { return }
        tableView.reloadData()
        context.coordinator.syncSelection(in: tableView)
    }

    private func addColumn(_ id: String, width: CGFloat, to tableView: NSTableView) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
        column.width = width
        column.minWidth = id == "name" ? 220 : width
        column.resizingMask = id == "name" ? .autoresizingMask : []
        tableView.addTableColumn(column)
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, FileTableSelectionDelegate {
        var parent: NativeFileTableView
        weak var tableView: NSTableView?
        private var isSyncingSelection = false

        init(_ parent: NativeFileTableView) {
            self.parent = parent
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            parent.items.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard parent.items.indices.contains(row), let tableColumn else { return nil }
            let item = parent.items[row]
            let identifier = tableColumn.identifier.rawValue
            let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as? NSTableCellView
                ?? makeCell(identifier: tableColumn.identifier)

            cell.textField?.font = NSFont(name: "Roboto", size: 14) ?? .systemFont(ofSize: 14)
            cell.textField?.textColor = NSColor(parent.tokens.text)
            cell.textField?.lineBreakMode = .byTruncatingTail
            cell.imageView?.isHidden = identifier != "name"

            switch identifier {
            case "name":
                cell.textField?.stringValue = item.name
                cell.imageView?.image = NSWorkspace.shared.icon(forFile: item.url.path)
            case "date":
                cell.textField?.stringValue = formatDate(item.modifiedAt)
            case "type":
                cell.textField?.stringValue = item.typeDescription
            case "size":
                cell.textField?.stringValue = formatSize(item)
            default:
                cell.textField?.stringValue = ""
            }

            return cell
        }

        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            FileRowView(tokens: parent.tokens, rowIndex: row)
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !isSyncingSelection, let tableView = notification.object as? NSTableView else { return }
            publishSelection(from: tableView)
        }

        func fileTableViewSelectionDidChange(_ tableView: NSTableView) {
            guard !isSyncingSelection else { return }
            publishSelection(from: tableView)
        }

        private func publishSelection(from tableView: NSTableView) {
            let urls = Set(tableView.selectedRowIndexes.compactMap { index in
                parent.items.indices.contains(index) ? parent.items[index].url : nil
            })
            parent.onSelectionChange(urls)
        }

        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            guard parent.items.indices.contains(row) else { return nil }
            let item = NSPasteboardItem()
            item.setString(parent.items[row].url.absoluteString, forType: .fileURL)
            item.setString(parent.items[row].url.path, forType: .string)
            return item
        }

        func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            context == .outsideApplication ? [.move, .delete] : .move
        }

        func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forRowIndexes rowIndexes: IndexSet) {
            let urls = Set(rowIndexes.compactMap { parent.items.indices.contains($0) ? parent.items[$0].url : nil })
            if !urls.isEmpty {
                parent.onSelectionChange(urls)
            }
        }

        func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
            guard droppedFileURLs(from: info).isEmpty == false else { return [] }
            tableView.setDropRow(max(row, 0), dropOperation: .on)
            return .move
        }

        func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
            let urls = droppedFileURLs(from: info)
            guard !urls.isEmpty else { return false }
            let destination: URL?
            if parent.items.indices.contains(row), parent.items[row].kind == .folder {
                destination = parent.items[row].url
            } else {
                destination = nil
            }
            parent.onDrop(urls, destination)
            return true
        }

        @objc func doubleClick(_ sender: NSTableView) {
            let row = sender.clickedRow >= 0 ? sender.clickedRow : sender.selectedRow
            guard parent.items.indices.contains(row) else { return }
            let reveal = NSApp.currentEvent?.modifierFlags.contains(.command) == true
            parent.onOpen(parent.items[row], reveal)
        }

        func menu(for row: Int) -> NSMenu? {
            guard parent.items.indices.contains(row) else { return nil }
            if parent.selectedURLs.contains(parent.items[row].url) == false {
                parent.onSelectionChange([parent.items[row].url])
            }
            let selectedItems = selectedItems(containing: parent.items[row])
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Open", action: #selector(openMenuItem(_:)), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Reveal in Finder", action: #selector(revealMenuItem(_:)), keyEquivalent: ""))
            let rename = NSMenuItem(title: "Rename", action: #selector(renameMenuItem(_:)), keyEquivalent: "")
            rename.isEnabled = selectedItems.count == 1
            menu.addItem(rename)
            menu.addItem(NSMenuItem(title: selectedItems.count == 1 ? "Move..." : "Move \(selectedItems.count) items...", action: #selector(moveMenuItem(_:)), keyEquivalent: ""))
            menu.addItem(.separator())
            menu.addItem(NSMenuItem(title: selectedItems.count == 1 ? "Move to Trash" : "Move \(selectedItems.count) items to Trash", action: #selector(trashMenuItem(_:)), keyEquivalent: ""))
            for item in menu.items {
                item.target = self
            }
            return menu
        }

        func syncSelection(in tableView: NSTableView) {
            let indexes = IndexSet(parent.items.enumerated().compactMap { index, item in
                parent.selectedURLs.contains(item.url) ? index : nil
            })
            guard tableView.selectedRowIndexes != indexes else { return }
            isSyncingSelection = true
            tableView.selectRowIndexes(indexes, byExtendingSelection: false)
            isSyncingSelection = false
        }

        @objc private func openMenuItem(_ sender: NSMenuItem) {
            guard let item = currentPrimaryItem() else { return }
            parent.onOpen(item, false)
        }

        @objc private func revealMenuItem(_ sender: NSMenuItem) {
            guard let item = currentPrimaryItem() else { return }
            parent.onOpen(item, true)
        }

        @objc private func renameMenuItem(_ sender: NSMenuItem) {
            guard let item = currentPrimaryItem() else { return }
            parent.onRename(item)
        }

        @objc private func moveMenuItem(_ sender: NSMenuItem) {
            parent.onMove(currentSelectedItems())
        }

        @objc private func trashMenuItem(_ sender: NSMenuItem) {
            parent.onTrash(currentSelectedItems())
        }

        private func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
            let cell = NSTableCellView()
            cell.identifier = identifier

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            cell.textField = textField
            cell.addSubview(textField)

            if identifier.rawValue == "name" {
                let imageView = NSImageView()
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.imageScaling = .scaleProportionallyDown
                cell.imageView = imageView
                cell.addSubview(imageView)

                NSLayoutConstraint.activate([
                    imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                    imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    imageView.widthAnchor.constraint(equalToConstant: 18),
                    imageView.heightAnchor.constraint(equalToConstant: 18),
                    textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 8),
                    textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                    textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                ])
            } else {
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                    textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                    textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                ])
            }

            return cell
        }

        private func droppedFileURLs(from info: NSDraggingInfo) -> [URL] {
            let pasteboard = info.draggingPasteboard
            guard let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] else {
                return []
            }
            return objects
        }

        private func selectedItems(containing item: FileItem) -> [FileItem] {
            if parent.selectedURLs.contains(item.url) {
                return parent.items.filter { parent.selectedURLs.contains($0.url) }
            }
            return [item]
        }

        private func currentSelectedItems() -> [FileItem] {
            parent.items.filter { parent.selectedURLs.contains($0.url) }
        }

        private func currentPrimaryItem() -> FileItem? {
            if let selected = currentSelectedItems().first {
                return selected
            }
            guard let row = tableView?.clickedRow, parent.items.indices.contains(row) else { return nil }
            return parent.items[row]
        }

        private func formatDate(_ date: Date?) -> String {
            guard let date else { return "-" }
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }

        private func formatSize(_ item: FileItem) -> String {
            guard item.kind != .folder else { return "-" }
            return ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file)
        }
    }
}

private final class FileTableView: NSTableView {
    var menuProvider: ((Int) -> NSMenu?)?
    weak var selectionDelegate: FileTableSelectionDelegate?
    private var dragSelectionAnchorRow: Int?
    private var isRangeSelecting = false

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let row = self.row(at: point)
        return menuProvider?(row)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: point)
        let clickedSelectedRow = clickedRow >= 0 && selectedRowIndexes.contains(clickedRow)

        if clickedSelectedRow {
            super.mouseDown(with: event)
            return
        }

        dragSelectionAnchorRow = clickedRow >= 0 ? clickedRow : nil
        isRangeSelecting = false
        applySelection(clickedRow: clickedRow, modifiers: event.modifierFlags)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let anchor = dragSelectionAnchorRow else {
            super.mouseDragged(with: event)
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        let currentRow = row(at: point)
        guard currentRow >= 0 else { return }

        isRangeSelecting = true
        let range = min(anchor, currentRow)...max(anchor, currentRow)
        selectRowIndexes(IndexSet(integersIn: range), byExtendingSelection: false)
        publishSelection()
    }

    override func mouseUp(with event: NSEvent) {
        if isRangeSelecting {
            publishSelection()
        }
        dragSelectionAnchorRow = nil
        isRangeSelecting = false
    }

    private func applySelection(clickedRow: Int, modifiers: NSEvent.ModifierFlags) {
        guard clickedRow >= 0 else {
            deselectAll(nil)
            publishSelection()
            return
        }

        if modifiers.contains(.command) {
            if selectedRowIndexes.contains(clickedRow) {
                deselectRow(clickedRow)
            } else {
                selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: true)
            }
        } else if modifiers.contains(.shift), selectedRow >= 0 {
            let range = min(selectedRow, clickedRow)...max(selectedRow, clickedRow)
            selectRowIndexes(IndexSet(integersIn: range), byExtendingSelection: false)
        } else {
            selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
        }
        publishSelection()
    }

    private func publishSelection() {
        selectionDelegate?.fileTableViewSelectionDidChange(self)
    }
}

private protocol FileTableSelectionDelegate: AnyObject {
    func fileTableViewSelectionDidChange(_ tableView: NSTableView)
}

private final class FileRowView: NSTableRowView {
    let tokens: ThemeTokens
    let rowIndex: Int

    init(tokens: ThemeTokens, rowIndex: Int) {
        self.tokens = tokens
        self.rowIndex = rowIndex
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawBackground(in dirtyRect: NSRect) {
        let color = rowIndex % 2 == 0 ? NSColor(tokens.rowA) : NSColor(tokens.rowB)
        color.setFill()
        dirtyRect.fill()
    }

    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }
        NSColor(tokens.rowSelected).setFill()
        dirtyRect.fill()
    }
}
