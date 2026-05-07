import Foundation

public struct FileItem: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable {
        case file
        case folder
        case other
    }

    public var id: URL { url }
    public let url: URL
    public let name: String
    public let kind: Kind
    public let size: Int64
    public let modifiedAt: Date?
    public let typeDescription: String

    public init(
        url: URL,
        name: String,
        kind: Kind,
        size: Int64,
        modifiedAt: Date?,
        typeDescription: String
    ) {
        self.url = url
        self.name = name
        self.kind = kind
        self.size = size
        self.modifiedAt = modifiedAt
        self.typeDescription = typeDescription
    }
}
