import Foundation
import Testing
@testable import DesktopFileWidgetCore

@Suite("FileSystemService")
struct FileSystemServiceTests {
    @Test("lists visible items with metadata and excludes hidden dot files by default")
    func listsVisibleItems() throws {
        let fixture = try Fixture()
        try "alpha".write(to: fixture.url.appendingPathComponent("alpha.txt"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: fixture.url.appendingPathComponent("Folder"), withIntermediateDirectories: false)
        try "hidden".write(to: fixture.url.appendingPathComponent(".secret"), atomically: true, encoding: .utf8)

        let service = FileSystemService()
        let items = try service.listItems(in: fixture.url)

        #expect(items.map(\.name).sorted() == ["Folder", "alpha.txt"])
        #expect(items.first(where: { $0.name == "Folder" })?.kind == .folder)
        #expect(items.first(where: { $0.name == "alpha.txt" })?.kind == .file)
    }

    @Test("sorts folders before files and then by requested key")
    func sortsItems() throws {
        let oldDate = Date(timeIntervalSince1970: 100)
        let newDate = Date(timeIntervalSince1970: 200)
        let items = [
            FileItem(url: URL(fileURLWithPath: "/tmp/b.txt"), name: "b.txt", kind: .file, size: 20, modifiedAt: oldDate, typeDescription: "Text"),
            FileItem(url: URL(fileURLWithPath: "/tmp/A"), name: "A", kind: .folder, size: 0, modifiedAt: newDate, typeDescription: "Folder"),
            FileItem(url: URL(fileURLWithPath: "/tmp/a.txt"), name: "a.txt", kind: .file, size: 10, modifiedAt: newDate, typeDescription: "Text")
        ]

        #expect(FileSorter.sorted(items, by: .name, ascending: true).map(\.name) == ["A", "a.txt", "b.txt"])
        #expect(FileSorter.sorted(items, by: .size, ascending: false).map(\.name) == ["A", "b.txt", "a.txt"])
    }

    @Test("rename refuses to overwrite an existing item")
    func renameRefusesOverwrite() throws {
        let fixture = try Fixture()
        let source = fixture.url.appendingPathComponent("source.txt")
        let destinationName = "target.txt"
        try "source".write(to: source, atomically: true, encoding: .utf8)
        try "target".write(to: fixture.url.appendingPathComponent(destinationName), atomically: true, encoding: .utf8)

        let service = FileSystemService()

        #expect(throws: FileOperationError.destinationExists) {
            try service.renameItem(at: source, to: destinationName)
        }
    }

    @Test("move refuses to overwrite an existing item")
    func moveRefusesOverwrite() throws {
        let fixture = try Fixture()
        let destinationFolder = fixture.url.appendingPathComponent("Destination")
        try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: false)
        let source = fixture.url.appendingPathComponent("report.pdf")
        try "source".write(to: source, atomically: true, encoding: .utf8)
        try "target".write(to: destinationFolder.appendingPathComponent("report.pdf"), atomically: true, encoding: .utf8)

        let service = FileSystemService()

        #expect(throws: FileOperationError.destinationExists) {
            try service.moveItem(at: source, toFolder: destinationFolder)
        }
    }
}

private struct Fixture {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopFileWidgetTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
