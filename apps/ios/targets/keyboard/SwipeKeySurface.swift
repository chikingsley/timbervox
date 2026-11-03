import SwiftUI
import UIKit

enum KeyboardPalette {
  static let keyUIColor = UIColor { traits in
    traits.userInterfaceStyle == .dark ? UIColor(white: 0.31, alpha: 1) : .white
  }
  static let specialUIColor = UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(white: 0.18, alpha: 1) : UIColor.systemGray3
  }
  static let pressedKeyUIColor = UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(white: 0.42, alpha: 1) : UIColor.systemGray3
  }
  static let pressedSpecialUIColor = UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(white: 0.28, alpha: 1) : UIColor.systemGray2
  }

  static let key = Color(uiColor: keyUIColor)
  static let specialKey = Color(uiColor: specialUIColor)
  static let pressedKey = Color(uiColor: pressedKeyUIColor)
  static let pressedSpecialKey = Color(uiColor: pressedSpecialUIColor)
}

struct SwipeKeySurface: View {
  @ObservedObject var model: KeyboardModel
  @State private var trail: [SwipePoint] = []
  @State private var activeControl: KeyboardControlKey?

  private let digitRow = Array("1234567890")
  private let rows = [Array("qwertyuiop"), Array("asdfghjkl"), Array("zxcvbnm")]

  var body: some View {
    GeometryReader { geometry in
      let layout = makeLayout(size: geometry.size)
      ZStack(alignment: .topLeading) {
        // The grid splits into faces and glyphs so the trail can sit between
        // them: it glides over the key faces but never smears the letters.
        // Both layers are equatable, so per-sample trail updates only redraw
        // the trail shape while a finger moves.
        KeyFacesView(
          frames: layout.frames,
          shiftFrame: layout.shiftFrame,
          deleteFrame: layout.deleteFrame
        )
        .equatable()

        if model.swipeEnabled, trail.count > 1 {
          SwipeTrailShape(points: trail.map(\.location))
            .stroke(
              LinearGradient(
                colors: [.cyan.opacity(0.8), .blue.opacity(0.95)],
                startPoint: .leading,
                endPoint: .trailing
              ),
              style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
            )
            .allowsHitTesting(false)
        }

        KeyGlyphsView(
          frames: layout.frames,
          shiftFrame: layout.shiftFrame,
          deleteFrame: layout.deleteFrame,
          shifted: model.shifted
        )
        .equatable()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            if activeControl == nil,
              let control = layout.control(at: value.startLocation)
            {
              activeControl = control
              if case .delete = control {
                model.beginDeleting()
              }
            }
            trail.append(
              SwipePoint(
                location: value.location,
                timestamp: ProcessInfo.processInfo.systemUptime
              )
            )
          }
          .onEnded { value in
            trail.append(
              SwipePoint(
                location: value.location,
                timestamp: ProcessInfo.processInfo.systemUptime
              )
            )
            if let activeControl {
              switch activeControl {
              case .delete:
                model.endDeleting()
              case .shift:
                model.toggleShift()
              }
              self.activeControl = nil
              trail.removeAll(keepingCapacity: true)
              return
            }
            let distance = trailDistance(trail.map(\.location))
            if distance < 22 {
              if let control = layout.control(at: value.location) {
                switch control {
                case .delete: model.deleteBackward()
                case .shift: model.toggleShift()
                }
              } else if let key = layout.key(at: value.location) {
                model.insert(String(key))
              }
            } else {
              model.handleSwipe(samples: trail, layout: layout)
            }
            withAnimation(.easeOut(duration: 0.16)) {
              trail.removeAll(keepingCapacity: true)
            }
          }
      )
      .onDisappear {
        model.endDeleting()
      }
    }
  }

  private func makeLayout(size: CGSize) -> KeyLayout {
    let rowHeight = size.height / 4
    var frames: [Character: CGRect] = [:]
    let digitWidth = size.width / CGFloat(digitRow.count)
    for (column, key) in digitRow.enumerated() {
      frames[key] = CGRect(
        x: CGFloat(column) * digitWidth + 2.5,
        y: 2.5,
        width: digitWidth - 5,
        height: rowHeight - 5
      )
    }
    for (rowIndex, row) in rows.prefix(2).enumerated() {
      let sideInset: CGFloat = rowIndex == 0 ? 0 : size.width * 0.045
      let available = size.width - sideInset * 2
      let keyWidth = available / CGFloat(row.count)
      for (column, key) in row.enumerated() {
        frames[key] = CGRect(
          x: sideInset + CGFloat(column) * keyWidth + 2.5,
          y: CGFloat(rowIndex + 1) * rowHeight + 2.5,
          width: keyWidth - 5,
          height: rowHeight - 5
        )
      }
    }

    let controlWidth = min(46, max(40, size.width * 0.13))
    let controlGap: CGFloat = 7
    let thirdRow = rows[2]
    let lettersStart = controlWidth + controlGap
    let lettersWidth = size.width - (lettersStart * 2)
    let letterWidth = lettersWidth / CGFloat(thirdRow.count)
    for (column, key) in thirdRow.enumerated() {
      frames[key] = CGRect(
        x: lettersStart + CGFloat(column) * letterWidth + 2.5,
        y: rowHeight * 3 + 2.5,
        width: letterWidth - 5,
        height: rowHeight - 5
      )
    }

    return KeyLayout(
      frames: frames,
      size: size,
      shiftFrame: CGRect(x: 2.5, y: rowHeight * 3 + 2.5, width: controlWidth - 5, height: rowHeight - 5),
      deleteFrame: CGRect(
        x: size.width - controlWidth + 2.5,
        y: rowHeight * 3 + 2.5,
        width: controlWidth - 5,
        height: rowHeight - 5
      )
    )
  }

  private func trailDistance(_ points: [CGPoint]) -> CGFloat {
    zip(points, points.dropFirst()).reduce(0) { result, pair in
      result + hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
    }
  }
}

private struct KeyFacesView: View, Equatable {
  let frames: [Character: CGRect]
  let shiftFrame: CGRect
  let deleteFrame: CGRect

  static func == (lhs: KeyFacesView, rhs: KeyFacesView) -> Bool {
    lhs.frames == rhs.frames && lhs.shiftFrame == rhs.shiftFrame
      && lhs.deleteFrame == rhs.deleteFrame
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      ForEach(frames.keys.sorted(), id: \.self) { key in
        face(frame: frames[key] ?? .zero, special: false)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(String(key))
          .accessibilityIdentifier("key-\(key)")
          .accessibilityAddTraits(.isButton)
      }
      face(frame: shiftFrame, special: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Shift")
        .accessibilityIdentifier("key-shift")
        .accessibilityAddTraits(.isButton)
      face(frame: deleteFrame, special: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Delete")
        .accessibilityIdentifier("key-delete")
        .accessibilityAddTraits(.isButton)
    }
  }

  private func face(frame: CGRect, special: Bool) -> some View {
    RoundedRectangle(cornerRadius: 6, style: .continuous)
      .fill(special ? KeyboardPalette.specialKey : KeyboardPalette.key)
      .overlay {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .stroke(.black.opacity(special ? 0.12 : 0.16), lineWidth: 0.75)
      }
      .shadow(color: .black.opacity(special ? 0.12 : 0.18), radius: 0.5, y: 1)
      .frame(width: frame.width, height: frame.height)
      .position(x: frame.midX, y: frame.midY)
  }
}

private struct KeyGlyphsView: View, Equatable {
  let frames: [Character: CGRect]
  let shiftFrame: CGRect
  let deleteFrame: CGRect
  let shifted: Bool

  static func == (lhs: KeyGlyphsView, rhs: KeyGlyphsView) -> Bool {
    lhs.frames == rhs.frames && lhs.shiftFrame == rhs.shiftFrame
      && lhs.deleteFrame == rhs.deleteFrame && lhs.shifted == rhs.shifted
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      ForEach(frames.keys.sorted(), id: \.self) { key in
        glyph(
          shifted ? String(key).uppercased() : String(key),
          frame: frames[key] ?? .zero
        )
      }
      glyph(systemName: shifted ? "shift.fill" : "shift", frame: shiftFrame)
      glyph(systemName: "delete.left", frame: deleteFrame)
    }
  }

  private func glyph(_ text: String, frame: CGRect) -> some View {
    Text(text)
      .font(.system(size: 21))
      .foregroundStyle(Color(uiColor: .label))
      .frame(width: frame.width, height: frame.height)
      .position(x: frame.midX, y: frame.midY)
  }

  private func glyph(systemName: String, frame: CGRect) -> some View {
    Image(systemName: systemName)
      .foregroundStyle(Color(uiColor: .label))
      .frame(width: frame.width, height: frame.height)
      .position(x: frame.midX, y: frame.midY)
  }
}

private struct SwipeTrailShape: Shape {
  let points: [CGPoint]

  func path(in rect: CGRect) -> Path {
    var path = Path()
    guard let first = points.first else { return path }
    path.move(to: first)
    for point in points.dropFirst() {
      path.addLine(to: point)
    }
    return path
  }
}

struct AlternateKeySurface: View {
  @ObservedObject var model: KeyboardModel

  // SwiftKey arrangement: digits always on top, one symbol family per page,
  // punctuation anchored on the bottom row beside the page toggle.
  private let digitRow = Array("1234567890").map(String.init)
  private let bracketRow = ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="]
  private let dashRow = ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""]
  private let symbolRow = ["_", "\\", "|", "~", "<", ">", "₽", "€", "£", "•"]
  private let punctuationRow = [".", ",", "?", "!", "'"]

  var body: some View {
    VStack(spacing: 5) {
      keyRow(digitRow)
      if model.page == .symbols {
        keyRow(symbolRow)
      } else {
        keyRow(bracketRow)
        keyRow(dashRow)
      }
      HStack(spacing: 5) {
        Button {
          model.toggleSymbols()
        } label: {
          Text(model.page == .symbols ? "123" : "#+=")
            .font(.system(size: 13, weight: .medium))
            .frame(width: 48)
            .frame(maxHeight: .infinity)
        }
        .buttonStyle(KeyboardSpecialKeyStyle())

        ForEach(punctuationRow, id: \.self) { key in
          Button {
            model.insert(key)
          } label: {
            Text(key)
              .font(.system(size: 20))
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
          .buttonStyle(KeyboardKeyStyle())
        }

        Button(action: model.deleteBackward) {
          Image(systemName: "delete.left")
            .font(.system(size: 17, weight: .medium))
            .frame(width: 48)
            .frame(maxHeight: .infinity)
        }
        .buttonStyle(KeyboardSpecialKeyStyle())
      }
      if model.page == .symbols {
        Spacer(minLength: 0)
      }
    }
  }

  private func keyRow(_ keys: [String]) -> some View {
    HStack(spacing: 5) {
      ForEach(keys, id: \.self) { key in
        Button {
          model.insert(key)
        } label: {
          Text(key)
            .font(.system(size: 20))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(KeyboardKeyStyle())
      }
    }
  }
}
