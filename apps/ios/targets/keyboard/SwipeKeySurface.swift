import SwiftUI

struct KeyLayout {
  let frames: [Character: CGRect]

  func key(at point: CGPoint) -> Character? {
    frames.first(where: { $0.value.insetBy(dx: -4, dy: -4).contains(point) })?.key
  }
}

struct SwipeKeySurface: View {
  @ObservedObject var model: KeyboardModel
  @State private var trail: [CGPoint] = []

  private let rows = [Array("qwertyuiop"), Array("asdfghjkl"), Array("zxcvbnm")]

  var body: some View {
    GeometryReader { geometry in
      let layout = makeLayout(size: geometry.size)
      Canvas { context, _ in
        drawKeys(context: &context, layout: layout)
        drawTrail(context: &context)
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            trail.append(value.location)
          }
          .onEnded { value in
            trail.append(value.location)
            let distance = trailDistance(trail)
            if distance < 22, let key = layout.key(at: value.location) {
              model.insert(String(key))
            } else {
              model.handleSwipe(points: trail, layout: layout)
            }
            withAnimation(.easeOut(duration: 0.16)) {
              trail.removeAll(keepingCapacity: true)
            }
          }
      )
    }
  }

  private func makeLayout(size: CGSize) -> KeyLayout {
    let rowHeight = size.height / 3
    var frames: [Character: CGRect] = [:]
    for (rowIndex, row) in rows.enumerated() {
      let sideInset: CGFloat = rowIndex == 0 ? 0 : (rowIndex == 1 ? size.width * 0.045 : size.width * 0.14)
      let available = size.width - sideInset * 2
      let keyWidth = available / CGFloat(row.count)
      for (column, key) in row.enumerated() {
        frames[key] = CGRect(
          x: sideInset + CGFloat(column) * keyWidth + 2.5,
          y: CGFloat(rowIndex) * rowHeight + 2.5,
          width: keyWidth - 5,
          height: rowHeight - 5
        )
      }
    }
    return KeyLayout(frames: frames)
  }

  private func drawKeys(context: inout GraphicsContext, layout: KeyLayout) {
    for (key, frame) in layout.frames {
      let rect = RoundedRectangle(cornerRadius: 6, style: .continuous).path(in: frame)
      context.fill(rect, with: .color(Color(uiColor: .systemBackground)))
      context.addFilter(.shadow(color: .black.opacity(0.16), radius: 0.5, y: 1))
      context.stroke(rect, with: .color(.black.opacity(0.04)), lineWidth: 0.5)
      context.draw(
        Text(model.shifted ? String(key).uppercased() : String(key))
          .font(.system(size: 21)),
        at: CGPoint(x: frame.midX, y: frame.midY)
      )
    }
  }

  private func drawTrail(context: inout GraphicsContext) {
    guard trail.count > 1 else { return }
    var path = Path()
    path.move(to: trail[0])
    for point in trail.dropFirst() {
      path.addLine(to: point)
    }
    context.stroke(
      path,
      with: .linearGradient(
        Gradient(colors: [.cyan.opacity(0.45), .blue.opacity(0.88)]),
        startPoint: trail[0],
        endPoint: trail.last ?? trail[0]
      ),
      style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
    )
  }

  private func trailDistance(_ points: [CGPoint]) -> CGFloat {
    zip(points, points.dropFirst()).reduce(0) { result, pair in
      result + hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
    }
  }
}
