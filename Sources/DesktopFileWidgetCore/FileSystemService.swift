import AppKit
import Foundation
import UniformTypeIdentifiers

public enum FileOperationError: LocalizedError, Equatable {
    case destinationExists
    case invalidName
    case inaccessibleFolder

    public var errorDescription: String? {
        switch self {
        case .destinationExists:
            "An item with that name already exists."
        case .invalidName:
            "The name is empty or contains a path separator."
        case .inaccessibleFolder:
            "The folder could not be accessed."
        }
    }
}

public struct FileSystemService {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func listItems(in folder: URL, includeHidden: Bool = false) throws -> [FileItem] {
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isRegularFileKey,
            .isPackageKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .localizedTypeDescriptionKey,
            .typeIdentifierKey,
            .isHiddenKey
        ]
        let options: FileManager.DirectoryEnumerationOptions = includeHidden ? [] : [.skipsHiddenFiles]
        let urls = try fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: Array(keys),
            options: options
        )

        return try urls.map { url in
            let values = try url.resourceValues(forKeys: keys)
            let isDirectory = values.isDirectory == true
            let kind: FileItem.Kind = isDirectory ? .folder : (values.isRegularFile == true ? .file : .other)
            let size = Int64(values.fileSize ?? 0)
            let typeDescription = values.localizedTypeDescription
                ?? UTType(filenameExtension: url.pathExtension)?.localizedDescription
                ?? (isDirectory ? "Folder" : "File")

            return FileItem(
                url: url,
                name: url.lastPathComponent,
                kind: kind,
                size: size,
                modifiedAt: values.contentModificationDate,
                typeDescription: typeDescription
            )
        }
    }

    public func renameItem(at source: URL, to newName: String) throws -> URL {
        let cleanName = try validateItemName(newName)
        let destination = source.deletingLastPathComponent().appendingPathComponent(cleanName)
        try ensureDestinationDoesNotExist(destination)
        try fileManager.moveItem(at: source, to: destination)
        return destination
    }

    public func moveItem(at source: URL, toFolder folder: URL) throws -> URL {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw FileOperationError.inaccessibleFolder
        }
        let destination = folder.appendingPathComponent(source.lastPathComponent)
        try ensureDestinationDoesNotExist(destination)
        try fileManager.moveItem(at: source, to: destination)
        return destination
    }

    public func createFolder(named name: String, in parent: URL) throws -> URL {
        let cleanName = try validateItemName(name)
        let destination = parent.appendingPathComponent(cleanName)
        try ensureDestinationDoesNotExist(destination)
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: false)
        return destination
    }

    public func trashItem(at url: URL) throws {
        var resultingURL: NSURL?
        try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
    }

    public func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public func openWithDefaultApp(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    private func validateItemName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("/") else {
            throw FileOperationError.invalidName
        }
        return trimmed
    }

    private func ensureDestinationDoesNotExist(_ destination: URL) throws {
        if fileManager.fileExists(atPath: destination.path) {
            throw FileOperationError.destinationExists
        }
    }
}
