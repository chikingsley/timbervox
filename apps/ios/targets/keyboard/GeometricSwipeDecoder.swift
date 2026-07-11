import CoreGraphics
import Foundation

protocol SwipeDecoding {
  func predictions(for points: [CGPoint], layout: KeyLayout) -> [String]
}

struct GeometricSwipeDecoder: SwipeDecoding {
  private let sampleCount = 24
  private let vocabulary = CommonWords.values

  func predictions(for points: [CGPoint], layout: KeyLayout) -> [String] {
    let observed = resample(points, count: sampleCount)
    guard let firstPoint = observed.first, let lastPoint = observed.last else { return [] }

    return vocabulary.compactMap { word -> (String, CGFloat)? in
      guard let first = word.first,
            let last = word.last,
            let firstFrame = layout.frames[first],
            let lastFrame = layout.frames[last]
      else { return nil }

      let startDistance = hypot(firstPoint.x - firstFrame.midX, firstPoint.y - firstFrame.midY)
      let endDistance = hypot(lastPoint.x - lastFrame.midX, lastPoint.y - lastFrame.midY)
      guard startDistance < 58, endDistance < 58 else { return nil }

      let template = word.compactMap { character -> CGPoint? in
        layout.frames[character].map { CGPoint(x: $0.midX, y: $0.midY) }
      }
      guard template.count == word.count else { return nil }
      let normalizedTemplate = resample(template, count: sampleCount)
      let shapeError = zip(observed, normalizedTemplate).reduce(CGFloat.zero) { total, pair in
        total + hypot(pair.0.x - pair.1.x, pair.0.y - pair.1.y)
      } / CGFloat(sampleCount)
      let lengthPenalty = abs(CGFloat(word.count) - estimatedKeyCount(points, layout: layout)) * 2.5
      return (word, shapeError + (startDistance + endDistance) * 0.55 + lengthPenalty)
    }
    .sorted { $0.1 < $1.1 }
    .prefix(3)
    .map(\.0)
  }

  private func estimatedKeyCount(_ points: [CGPoint], layout: KeyLayout) -> CGFloat {
    var visited: [Character] = []
    for point in points {
      guard let key = layout.key(at: point), visited.last != key else { continue }
      visited.append(key)
    }
    return CGFloat(visited.count)
  }

  private func resample(_ points: [CGPoint], count: Int) -> [CGPoint] {
    guard points.count > 1, count > 1 else { return points }
    let distances = zip(points, points.dropFirst()).map { pair in
      hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
    }
    let total = distances.reduce(0, +)
    guard total > 0 else { return Array(repeating: points[0], count: count) }

    var result: [CGPoint] = []
    var segmentIndex = 0
    var segmentStartDistance: CGFloat = 0
    for sampleIndex in 0..<count {
      let target = total * CGFloat(sampleIndex) / CGFloat(count - 1)
      while segmentIndex < distances.count - 1,
            segmentStartDistance + distances[segmentIndex] < target {
        segmentStartDistance += distances[segmentIndex]
        segmentIndex += 1
      }
      let segmentLength = max(distances[segmentIndex], 0.001)
      let fraction = (target - segmentStartDistance) / segmentLength
      let start = points[segmentIndex]
      let end = points[segmentIndex + 1]
      result.append(CGPoint(
        x: start.x + (end.x - start.x) * fraction,
        y: start.y + (end.y - start.y) * fraction
      ))
    }
    return result
  }
}

private enum CommonWords {
  static let values: [String] = """
  about after again all also always am an and another any are around as ask at away back be because been before being best better between both but by call came can change come could day did different do does down each end even every few find first for from get give go good great had has have he help her here him his home how i if in into is it its just keep know last like little long look made make many may me more most much must my need never new next no not now of off old on once one only or other our out over own people place put right same say see she should show so some something still take tell than that the their them then there these they thing think this those through time to too try two under up us use very want was way we well went were what when where which while who why will with work would year yes you your
  apple audio background button cloud current dictation expo fast keyboard language microphone mobile model recording realtime session settings shortcut speak speech swipe timber timbervox transcript transcription voice voxtral words write
  """.split(whereSeparator: { $0.isWhitespace }).map(String.init)
}
