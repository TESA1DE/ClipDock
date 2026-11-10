import Foundation

public struct History: Sendable {
    public private(set) var items: [ClipboardItem]
    public init(items: [ClipboardItem] = []) { self.items = items }
    public var ordered: [ClipboardItem] {
        items.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.createdAt > b.createdAt
        }
    }
    public func search(_ query: String) -> [ClipboardItem] { ordered.filter { $0.matches(query) } }
    /// Repeated values reuse their identity and pin state, and move to the most recent position.
    public mutating func insert(_ item: ClipboardItem, limit: Int, imageBudget: Int = 200 * 1_024 * 1_024) {
        if let index = items.firstIndex(where: { $0.fingerprint == item.fingerprint }) {
            items[index].createdAt = item.createdAt
        } else { items.append(item) }
        trim(limit: limit, imageBudget: imageBudget)
    }
    public mutating func trim(limit: Int, imageBudget: Int = 200 * 1_024 * 1_024) {
        let recent = items.filter { !$0.isPinned }.sorted { $0.createdAt > $1.createdAt }
        var bytes = 0
        let kept = recent.enumerated().compactMap { index, item -> UUID? in
            guard limit == 0 || index < limit else { return nil }
            if item.type == .image {
                guard bytes + item.imageBytes <= imageBudget else { return nil }
                bytes += item.imageBytes
            }
            return item.id
        }
        let ids = Set(kept)
        items.removeAll { !$0.isPinned && !ids.contains($0.id) }
    }
    @discardableResult
    public mutating func expire(olderThan age: TimeInterval, now: Date = Date()) -> Bool {
        guard age > 0 else { return false }
        let count = items.count
        items.removeAll { !$0.isPinned && now.timeIntervalSince($0.createdAt) >= age }
        return items.count != count
    }
    public mutating func togglePin(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned.toggle()
    }
    public mutating func delete(_ id: UUID) { items.removeAll { $0.id == id } }
    public mutating func clear(includePinned: Bool = false) { items.removeAll { includePinned || !$0.isPinned } }
}
