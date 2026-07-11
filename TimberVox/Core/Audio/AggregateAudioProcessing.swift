@preconcurrency import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation

struct AggregateInputSnapshot: @unchecked Sendable {
  let microphoneSamples: [Float]
  let systemSamples: [Float]
  let hostTime: UInt64
}

final class AggregateMonoResampler {
  private let sourceFormat: AVAudioFormat
  private let outputFormat: AVAudioFormat
  private let converter: AVAudioConverter

  init(sourceSampleRate: Double) throws {
    guard
      let sourceFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: sourceSampleRate,
        channels: 1,
        interleaved: false
      ),
      let outputFormat = AggregateAudioFormat.format,
      let converter = AVAudioConverter(from: sourceFormat, to: outputFormat)
    else {
      throw AggregateAudioRecorderError.invalidConfiguration
    }
    self.sourceFormat = sourceFormat
    self.outputFormat = outputFormat
    self.converter = converter
  }

  func convert(_ samples: [Float]) throws -> [Float] {
    guard !samples.isEmpty else { return [] }
    guard
      let input = AVAudioPCMBuffer(
        pcmFormat: sourceFormat,
        frameCapacity: AVAudioFrameCount(samples.count)
      ),
      let inputData = input.floatChannelData?[0]
    else {
      throw AggregateAudioRecorderError.invalidConfiguration
    }
    input.frameLength = input.frameCapacity
    inputData.update(from: samples, count: samples.count)

    let ratio = outputFormat.sampleRate / sourceFormat.sampleRate
    let outputCapacity = AVAudioFrameCount(ceil(Double(samples.count) * ratio) + 64)
    guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
      throw AggregateAudioRecorderError.invalidConfiguration
    }

    let inputSupply = AggregateConverterInputSupply(buffer: input)
    var conversionError: NSError?
    let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
      inputSupply.next(status: inputStatus)
    }
    if let conversionError {
      throw conversionError
    }
    guard status != .error, let outputData = output.floatChannelData?[0] else {
      throw AggregateAudioRecorderError.conversionFailed
    }
    return Array(
      UnsafeBufferPointer(start: outputData, count: Int(output.frameLength))
    )
  }
}

private final class AggregateConverterInputSupply: @unchecked Sendable {
  private let buffer: AVAudioPCMBuffer
  private var isSupplied = false

  init(buffer: AVAudioPCMBuffer) {
    self.buffer = buffer
  }

  func next(
    status: UnsafeMutablePointer<AVAudioConverterInputStatus>
  ) -> AVAudioBuffer? {
    guard !isSupplied else {
      status.pointee = .noDataNow
      return nil
    }
    isSupplied = true
    status.pointee = .haveData
    return buffer
  }
}

enum AggregateAudioFormat {
  static let sampleRate = 16_000.0

  static var format: AVAudioFormat? {
    AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: sampleRate,
      channels: 1,
      interleaved: false
    )
  }

  static func makeFile(at url: URL) throws -> AVAudioFile {
    try AVAudioFile(
      forWriting: url,
      settings: [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: sampleRate,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
      ],
      commonFormat: .pcmFormatFloat32,
      interleaved: false
    )
  }

  static func write(_ samples: [Float], to file: AVAudioFile?) throws {
    guard !samples.isEmpty, let file, let format else { return }
    guard
      let buffer = AVAudioPCMBuffer(
        pcmFormat: format,
        frameCapacity: AVAudioFrameCount(samples.count)
      ),
      let data = buffer.floatChannelData?[0]
    else {
      throw AggregateAudioRecorderError.invalidConfiguration
    }
    buffer.frameLength = buffer.frameCapacity
    data.update(from: samples, count: samples.count)
    try file.write(from: buffer)
  }

  static func rootMeanSquare(_ samples: [Float]) -> Float {
    guard !samples.isEmpty else { return 0 }
    let sum = samples.reduce(Float.zero) { $0 + $1 * $1 }
    return sqrt(sum / Float(samples.count))
  }

  static func normalizedLevel(from samples: [Float]) -> Float {
    min(1, max(0, rootMeanSquare(samples) * 24))
  }
}
