import SwiftUI

struct DictionaryNoMatchesRow: View {
  let query: String

  var body: some View {
    HStack {
      Text("No entries match “\(query)”")
        .font(.system(size: 12))
        .foregroundStyle(.tertiary)
      Spacer()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
  }
}

struct DictionarySegmentButton: View {
  let title: String
  let count: Int
  let isSelected: Bool
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 5) {
        Text(title)
          .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
          .foregroundStyle(isSelected ? .primary : .secondary)
        Text("\(count)")
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(.tertiary)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 6)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(isSelected ? Theme.selectionFill : (hovering ? Theme.hoverFill : Color.clear))
      )
      .contentShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

struct DictionaryReplacementRow: View {
  @Binding var entry: DictionaryReplacement
  let onDelete: () -> Void
  @State private var hovering = false

  var body: some View {
    HStack(spacing: 10) {
      DictionaryEnableDot(isEnabled: $entry.isEnabled)

      Text(entry.match.capitalized)
        .font(.system(size: 13))
        .foregroundStyle(entry.isEnabled ? .primary : .tertiary)
      Image(systemName: "arrow.right")
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(.tertiary)
      Text(entry.replacement)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(entry.isEnabled ? .primary : .tertiary)

      Spacer()

      KeyChip(entry.source.badge)

      DictionaryDeleteButton(visible: hovering, action: onDelete)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .contentShape(Rectangle())
    .onHover { hovering = $0 }
  }
}

struct DictionaryRemovalRow: View {
  @Binding var entry: DictionaryRemoval
  let onDelete: () -> Void
  @State private var hovering = false

  var body: some View {
    HStack(spacing: 10) {
      DictionaryEnableDot(isEnabled: $entry.isEnabled)

      Text(entry.pattern)
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(entry.isEnabled ? .primary : .tertiary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))

      Text(entry.note)
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)

      Spacer()

      KeyChip("regex")

      DictionaryDeleteButton(visible: hovering, action: onDelete)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .contentShape(Rectangle())
    .onHover { hovering = $0 }
  }
}

struct DictionaryAddRow: View {
  let label: String
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: "plus")
          .font(.system(size: 11, weight: .medium))
        Text(label)
          .font(.system(size: 12))
        Spacer()
      }
      .foregroundStyle(hovering ? .primary : .secondary)
      .padding(.horizontal, 14)
      .padding(.vertical, 9)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

struct DictionaryVocabChip: View {
  let term: DictionaryVocabTerm
  let onDelete: () -> Void
  @State private var hovering = false

  var body: some View {
    HStack(spacing: 4) {
      Text(term.text)
        .font(.system(size: 12))
      if hovering {
        Button(action: onDelete) {
          Image(systemName: "xmark")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 4)
    .background(.primary.opacity(hovering ? 0.12 : 0.07), in: Capsule())
    .onHover { value in
      withAnimation(.easeInOut(duration: 0.12)) { hovering = value }
    }
  }
}

struct DictionaryChipFlow: Layout {
  var spacing: CGFloat = 6

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let width = proposal.width ?? .infinity
    return arrange(subviews: subviews, in: width).size
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let arrangement = arrange(subviews: subviews, in: bounds.width)
    for (subview, position) in zip(subviews, arrangement.positions) {
      subview.place(
        at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
        proposal: .unspecified
      )
    }
  }

  private func arrange(subviews: Subviews, in width: CGFloat) -> (size: CGSize, positions: [CGPoint]) {
    var positions: [CGPoint] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var maxX: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x > 0, x + size.width > width {
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
      }
      positions.append(CGPoint(x: x, y: y))
      rowHeight = max(rowHeight, size.height)
      x += size.width + spacing
      maxX = max(maxX, x - spacing)
    }

    return (CGSize(width: maxX, height: y + rowHeight), positions)
  }
}

private struct DictionaryEnableDot: View {
  @Binding var isEnabled: Bool

  var body: some View {
    Button {
      isEnabled.toggle()
    } label: {
      Circle()
        .fill(isEnabled ? Color.accentColor : Color.primary.opacity(0.15))
        .frame(width: 8, height: 8)
        .padding(4)
        .contentShape(Circle().inset(by: -4))
    }
    .buttonStyle(.plain)
    .help(isEnabled ? "Enabled — click to disable" : "Disabled — click to enable")
  }
}

private struct DictionaryDeleteButton: View {
  let visible: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "trash")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
    .buttonStyle(.plain)
    .opacity(visible ? 1 : 0)
    .help("Delete")
  }
}
