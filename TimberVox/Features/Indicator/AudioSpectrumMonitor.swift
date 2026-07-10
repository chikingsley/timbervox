import Accelerate
import Observation

/// FFT voice spectrum for the recording pill: mic samples → Hann window →
/// DFT (Accelerate) → mel-spaced bands (80 Hz–4 kHz) → dB → 0…1 bars with
/// fast-attack / slow-decay meter ballistics.
@MainActor
@Observable
final class AudioSpectrumMonitor {
  static let barCount = 16
  private static let fftSize = 2048
  private static let sampleRate: Float = 16000
  private static let minHz: Float = 80
  private static let maxHz: Float = 4000
  private static let decay: Float = 0.45
  /// Auto-gain: bars are scaled against the loudest band heard recently, so
  /// the display self-calibrates to any mic level. Window = top 26 dB.
  private static let dynamicRangeDb: Float = 26
  private static let referenceDecayDb: Float = 0.25
  private static let referenceFloorDb: Float = -55

  private(set) var bars: [Float] = Array(repeating: 0, count: AudioSpectrumMonitor.barCount)
  private var referenceDb: Float = -40

  private var window: [Float] = []
  private let hann = vDSP.window(
    ofType: Float.self,
    usingSequence: .hanningDenormalized,
    count: fftSize,
    isHalfWindow: false
  )
  private let dft = try? vDSP.DiscreteFourierTransform(
    count: fftSize,
    direction: .forward,
    transformType: .complexComplex,
    ofType: Float.self
  )

  /// Mel-spaced frequency bands mapped to DFT bin ranges: each bar covers a
  /// perceptually equal slice of the voice range, so energy spreads across
  /// the row instead of piling into the lowest bars.
  private static let bandRanges: [Range<Int>] = {
    let binHz = sampleRate / Float(fftSize)
    func mel(_ hz: Float) -> Float { 2595 * log10(1 + hz / 700) }
    func hz(_ mel: Float) -> Float { 700 * (pow(10, mel / 2595) - 1) }
    let melLow = mel(minHz)
    let melHigh = mel(maxHz)
    var edges = (0...barCount).map { index in
      max(1, Int(hz(melLow + (melHigh - melLow) * Float(index) / Float(barCount)) / binHz))
    }
    for index in 1..<edges.count {
      edges[index] = max(edges[index], edges[index - 1] + 1)
    }
    return (0..<barCount).map { edges[$0]..<edges[$0 + 1] }
  }()

  func reset() {
    window.removeAll()
    bars = Array(repeating: 0, count: Self.barCount)
    referenceDb = -40
  }

  func append(_ samples: [Float]) {
    window.append(contentsOf: samples)
    guard window.count >= Self.fftSize else { return }
    let frame = Array(window.suffix(Self.fftSize))
    window.removeAll(keepingCapacity: true)
    compute(frame)
  }

  private func compute(_ input: [Float]) {
    guard let dft else { return }

    let windowed = vDSP.multiply(input, hann)
    let imagIn = [Float](repeating: 0, count: Self.fftSize)
    var realOut = [Float](repeating: 0, count: Self.fftSize)
    var imagOut = [Float](repeating: 0, count: Self.fftSize)
    dft.transform(
      inputReal: windowed, inputImaginary: imagIn,
      outputReal: &realOut, outputImaginary: &imagOut
    )

    var magnitudes = [Float](repeating: 0, count: Self.fftSize / 2)
    realOut.withUnsafeMutableBufferPointer { real in
      guard let realBaseAddress = real.baseAddress else { return }
      imagOut.withUnsafeMutableBufferPointer { imag in
        guard let imaginaryBaseAddress = imag.baseAddress else { return }
        var complex = DSPSplitComplex(realp: realBaseAddress, imagp: imaginaryBaseAddress)
        vDSP_zvabs(&complex, 1, &magnitudes, 1, vDSP_Length(Self.fftSize / 2))
      }
    }

    let amplitudeScale = Float(Self.fftSize) / 2
    var bandDbs = [Float]()
    bandDbs.reserveCapacity(Self.barCount)
    for band in Self.bandRanges {
      let peak = (magnitudes[band].max() ?? 0) / amplitudeScale
      bandDbs.append(20 * log10(max(peak, 1e-7)))
    }

    let frameMax = bandDbs.max() ?? Self.referenceFloorDb
    referenceDb = max(
      max(frameMax, referenceDb - Self.referenceDecayDb),
      Self.referenceFloorDb
    )
    TimberVoxLog.audio.notice(
      "spectrum frameMaxDb=\(frameMax, format: .fixed(precision: 1)) refDb=\(self.referenceDb, format: .fixed(precision: 1))"
    )

    let floor = referenceDb - Self.dynamicRangeDb
    var next = [Float]()
    next.reserveCapacity(Self.barCount)
    for (index, db) in bandDbs.enumerated() {
      let normalized = min(1, max(0, (db - floor) / Self.dynamicRangeDb))
      next.append(max(normalized, bars[index] * Self.decay))
    }
    bars = next
  }
}
