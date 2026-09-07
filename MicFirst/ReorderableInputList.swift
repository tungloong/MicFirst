import SwiftUI

/// The menu and Settings share one drag implementation, with stable device UIDs at the boundary.
struct ReorderableInputList<RowContent: View>: View {
    let rows: [InputPriorityRow]
    let rowHeight: CGFloat
    let maximumVisibleRows: Int
    var showsHandlesOnHover = false
    var horizontalInset: CGFloat = 0
    let move: (String, String?) -> Void
    @ViewBuilder let rowContent: (InputPriorityRow, InputPriorityDragHandle) -> RowContent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var coordinateSpace = UUID()
    @State private var isHovered = false
    @State private var draggedUID: String?
    @State private var insertionIndex: Int?
    @State private var dragOffset: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var dragStartScrollOffset: CGFloat = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var scrollDirection = 0
    @State private var scrollTask: Task<Void, Never>?
    @State private var width: CGFloat = 0

    private var height: CGFloat { CGFloat(min(rows.count, maximumVisibleRows)) * rowHeight }
    private var handlesAreVisible: Bool { !showsHandlesOnHover || isHovered || draggedUID != nil }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        rowContent(
                            row,
                            InputPriorityDragHandle(
                                height: rowHeight, coordinateSpace: coordinateSpace,
                                isVisible: handlesAreVisible,
                                changed: { updateDrag(row: row, value: $0, proxy: proxy) },
                                ended: finishDrag
                            )
                        )
                        .frame(height: rowHeight)
                        .id(row.id)
                        .accessibilityAction(named: Text("Move Up")) { move(row: row, direction: -1) }
                        .accessibilityAction(named: Text("Move Down")) { move(row: row, direction: 1) }
                        .background {
                            if draggedUID == row.id {
                                RoundedRectangle(cornerRadius: 8).fill(.regularMaterial)
                                    .padding(.horizontal, horizontalInset)
                            }
                        }
                        .shadow(color: .black.opacity(draggedUID == row.id ? 0.15 : 0), radius: 6, y: 3)
                        .offset(y: offset(for: row))
                        .zIndex(draggedUID == row.id ? 1 : 0)
                    }
                }
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: PriorityScrollOffsetKey.self,
                            value: geometry.frame(in: .named(coordinateSpace)).minY)
                    }
                }
                .overlay(alignment: .top) {
                    if let destination = destinationIndex {
                        Rectangle().fill(Color(nsColor: .systemBlue)).frame(height: 2)
                            .padding(.horizontal, horizontalInset + 8)
                            .offset(y: CGFloat(destination) * rowHeight)
                            .allowsHitTesting(false)
                    }
                }
            }
            .frame(height: height)
            .coordinateSpace(name: coordinateSpace)
            .background {
                GeometryReader { geometry in
                    Color.clear.onAppear { width = geometry.size.width }
                        .onChange(of: geometry.size.width) { width = $0 }
                }
            }
            .onPreferenceChange(PriorityScrollOffsetKey.self) {
                scrollOffset = $0
                updateDragPosition()
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: handlesAreVisible)
        .onChange(of: rows.map(\.id)) { _ in clearDrag() }
        .onDisappear { isHovered = false; clearDrag() }
        .onExitCommand { clearDrag() }
    }

    private var destinationIndex: Int? {
        guard let insertionIndex, let source = rows.firstIndex(where: { $0.id == draggedUID }) else { return nil }
        return insertionIndex > source ? insertionIndex - 1 : insertionIndex
    }

    private func updateDrag(row: InputPriorityRow, value: DragGesture.Value, proxy: ScrollViewProxy) {
        if draggedUID == nil { dragStartScrollOffset = scrollOffset }
        draggedUID = row.id
        dragTranslation = value.translation.height
        updateDragPosition()
        setAutoScroll(direction: value.location.y < 20 ? -1 : (value.location.y > height - 20 ? 1 : 0), proxy: proxy)
    }

    private func updateDragPosition() {
        guard let source = rows.firstIndex(where: { $0.id == draggedUID }) else { return }
        dragOffset = dragTranslation + dragStartScrollOffset - scrollOffset
        let location = CGFloat(source) * rowHeight + rowHeight / 2 + dragOffset
        insertionIndex = min(max(Int((location / rowHeight).rounded()), 0), rows.count)
    }

    private func setAutoScroll(direction: Int, proxy: ScrollViewProxy) {
        guard direction != scrollDirection, rows.count > maximumVisibleRows else { return }
        scrollTask?.cancel()
        scrollDirection = direction
        guard direction != 0 else { return }
        scrollTask = Task { @MainActor in
            while !Task.isCancelled && draggedUID != nil {
                do { try await Task.sleep(nanoseconds: 120_000_000) } catch { return }
                let index = direction < 0
                    ? max(0, Int(floor(-scrollOffset / rowHeight)) - 1)
                    : min(rows.count - 1, Int(ceil((height - scrollOffset) / rowHeight)))
                guard rows.indices.contains(index) else { return }
                proxy.scrollTo(rows[index].id, anchor: direction < 0 ? .top : .bottom)
            }
        }
    }

    private func offset(for row: InputPriorityRow) -> CGFloat {
        guard let source = rows.firstIndex(where: { $0.id == draggedUID }), let destination = destinationIndex,
            let index = rows.firstIndex(where: { $0.id == row.id })
        else { return 0 }
        if row.id == draggedUID {
            return min(max(dragOffset, -CGFloat(source) * rowHeight), CGFloat(rows.count - source - 1) * rowHeight)
        }
        if index > source && index <= destination { return -rowHeight }
        if index < source && index >= destination { return rowHeight }
        return 0
    }

    private func finishDrag(value: DragGesture.Value) {
        defer { clearDrag() }
        guard (0...width).contains(value.location.x), (0...height).contains(value.location.y),
            let uid = draggedUID, let destination = destinationIndex
        else { return }
        let remaining = rows.filter { $0.id != uid }
        move(uid, remaining.indices.contains(destination) ? remaining[destination].id : nil)
    }

    private func move(row: InputPriorityRow, direction: Int) {
        guard let index = rows.firstIndex(where: { $0.id == row.id }), rows.indices.contains(index + direction) else {
            return
        }
        let remaining = rows.filter { $0.id != row.id }
        let destination = index + direction
        move(row.id, remaining.indices.contains(destination) ? remaining[destination].id : nil)
    }

    private func clearDrag() {
        draggedUID = nil
        insertionIndex = nil
        dragOffset = 0
        scrollTask?.cancel()
        scrollTask = nil
        scrollDirection = 0
    }
}

struct InputPriorityDragHandle: View {
    let height: CGFloat
    let coordinateSpace: UUID
    let isVisible: Bool
    let changed: (DragGesture.Value) -> Void
    let ended: (DragGesture.Value) -> Void

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.tertiary)
            .frame(width: 14, height: height)
            .contentShape(Rectangle())
            .opacity(isVisible ? 1 : 0)
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .named(coordinateSpace))
                    .onChanged(changed).onEnded(ended)
            )
            .accessibilityHidden(true)
    }
}

private struct PriorityScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
