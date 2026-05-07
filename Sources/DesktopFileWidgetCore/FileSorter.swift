import Foundation

public enum SortKey: String, CaseIterable, Sendable {
    case name = "Name"
    case date = "Date"
    case type = "Type"
    case size = "Size"
}

public enum FileSorter {
    public static func sorted(_ items: [FileItem], by key: SortKey, ascending: Bool) -> [FileItem] {
        items.sorted { left, right in
            if left.kind == .folder, right.kind != .folder { return true }
            if left.kind != .folder, right.kind == .folder { return false }

            let orderedAscending: Bool
            switch key {
            case .name:
                orderedAscending = left.name.localizedStandardCompare(right.name) == .orderedAscending
            case .date:
                orderedAscending = (left.modifiedAt ?? .distantPast) < (right.modifiedAt ?? .distantPast)
            case .type:
                let typeComparison = left.typeDescription.localizedStandardCompare(right.typeDescription)
                orderedAscending = typeComparison == .orderedSame
                    ? left.name.localizedStandardCompare(right.name) == .orderedAscending
                    : typeComparison == .orderedAscending
            case .size:
                orderedAscending = left.size == right.size
                    ? left.name.localizedStandardCompare(right.name) == .orderedAscending
                    : left.size < right.size
            }

            return ascending ? orderedAscending : !orderedAscending
        }
    }
}
