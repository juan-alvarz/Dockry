import Foundation

/// Whether the Trash has anything in it. The Trash can't be listed without Full Disk
/// Access, but its number of entries can be read, and so can whether Finder's `.DS_Store`
/// is one of them.
public enum TrashState {
    public static func isFull(entryCount: Int, hasDSStore: Bool) -> Bool {
        entryCount - (hasDSStore ? 1 : 0) > 0
    }
}
