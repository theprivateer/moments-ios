import SwiftUI
import UniformTypeIdentifiers

struct ReorderableImageStrip<Item: Identifiable, Content: View>: View where Item.ID: Hashable {
    let items: [Item]
    let onMove: (IndexSet, Int) -> Void
    let content: (Item) -> Content

    @State private var draggedItemID: Item.ID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    content(item)
                        .opacity(draggedItemID == item.id ? 0.75 : 1.0)
                        .onDrag {
                            draggedItemID = item.id
                            return NSItemProvider(object: String(describing: item.id) as NSString)
                        }
                        .onDrop(
                            of: [UTType.text],
                            delegate: ReorderableImageDropDelegate(
                                destinationItem: item,
                                items: items,
                                draggedItemID: $draggedItemID,
                                onMove: onMove
                            )
                        )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .onDrop(of: [UTType.text], delegate: ReorderableImageStripOutsideDropDelegate(draggedItemID: $draggedItemID))
    }
}

private struct ReorderableImageDropDelegate<Item: Identifiable>: DropDelegate where Item.ID: Hashable {
    let destinationItem: Item
    let items: [Item]
    @Binding var draggedItemID: Item.ID?
    let onMove: (IndexSet, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedItemID,
              draggedItemID != destinationItem.id,
              let fromIndex = items.firstIndex(where: { $0.id == draggedItemID }),
              let toIndex = items.firstIndex(where: { $0.id == destinationItem.id }) else {
            return
        }

        withAnimation {
            onMove(IndexSet(integer: fromIndex), toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItemID = nil
        return true
    }
}

private struct ReorderableImageStripOutsideDropDelegate<ItemID: Hashable>: DropDelegate {
    @Binding var draggedItemID: ItemID?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItemID = nil
        return true
    }
}
