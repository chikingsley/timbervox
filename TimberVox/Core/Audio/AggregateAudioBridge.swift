import AudioToolbox
import CoreAudio
import Foundation
import Synchronization

struct AggregateAudioCaptureDiagnostics: Equatable, Sendable {
  var droppedChunks = 0
  var droppedFrames = 0
  var oversizedChunks = 0

  var isDegraded: Bool {
    droppedChunks > 0 || oversizedChunks > 0
  }
}

/// A preallocated single-producer/single-consumer bridge between Core Audio's
/// realtime IO callback and TimberVox's file/resampling pipeline.
final class AggregateAudioBridge: @unchecked Sendable {
  private final class Slot: @unchecked Sendable {
    let microphone: UnsafeMutablePointer<Float>
    let system: UnsafeMutablePointer<Float>
    var hostTime: UInt64 = 0
    var microphoneFrameCount = 0
    var systemFrameCount = 0

    init(maximumFrameCount: Int) {
      microphone = .allocate(capacity: maximumFrameCount)
      system = .allocate(capacity: maximumFrameCount)
    }

    deinit {
      microphone.deallocate()
      system.deallocate()
    }
  }

  private let accepting = Atomic<Bool>(true)
  private let createdHostTime = AudioGetCurrentHostTime()
  private let droppedChunks = Atomic<Int>(0)
  private let droppedFrames = Atomic<Int>(0)
  private let maximumFrameCount: Int
  private let lastValidInputHostTime = Atomic<UInt64>(0)
  private let oversizedChunks = Atomic<Int>(0)
  private let readIndex = Atomic<Int>(0)
  private let slots: [Slot]
  private let writeIndex = Atomic<Int>(0)

  init(slotCount: Int, maximumFrameCount: Int) {
    precondition(slotCount > 1)
    precondition(maximumFrameCount > 0)
    self.maximumFrameCount = maximumFrameCount
    slots = (0..<slotCount).map { _ in Slot(maximumFrameCount: maximumFrameCount) }
  }

  var hasPendingAudio: Bool {
    readIndex.load(ordering: .acquiring) != writeIndex.load(ordering: .acquiring)
  }

  var isAcceptingAudio: Bool {
    accepting.load(ordering: .acquiring)
  }

  func hasValidInputTimedOut(after seconds: TimeInterval) -> Bool {
    let lastInput = lastValidInputHostTime.load(ordering: .acquiring)
    let reference = lastInput == 0 ? createdHostTime : lastInput
    let now = AudioGetCurrentHostTime()
    guard now > reference else { return false }
    let elapsedNanoseconds = AudioConvertHostTimeToNanos(now - reference)
    return Double(elapsedNanoseconds) / 1_000_000_000 > seconds
  }

  var diagnostics: AggregateAudioCaptureDiagnostics {
    AggregateAudioCaptureDiagnostics(
      droppedChunks: droppedChunks.load(ordering: .acquiring),
      droppedFrames: droppedFrames.load(ordering: .acquiring),
      oversizedChunks: oversizedChunks.load(ordering: .acquiring)
    )
  }

  /// Called only by the Core Audio IO queue. This method performs bounded
  /// copies and arithmetic into memory allocated before capture starts.
  func push(
    inputData: UnsafePointer<AudioBufferList>,
    inputTime: AudioTimeStamp,
    microphoneChannelCount: Int,
    tapChannelCount: Int
  ) {
    guard accepting.load(ordering: .relaxed) else { return }
    let currentWriteIndex = writeIndex.load(ordering: .relaxed)
    let nextWriteIndex = (currentWriteIndex + 1) % slots.count
    guard nextWriteIndex != readIndex.load(ordering: .acquiring) else {
      lastValidInputHostTime.store(inputTime.mHostTime, ordering: .releasing)
      recordDroppedChunk(inputData: inputData)
      return
    }

    let buffers = UnsafeMutableAudioBufferListPointer(
      UnsafeMutablePointer(mutating: inputData)
    )
    guard buffers.count > 1 else { return }
    let tapIndex = buffers.count - 1
    let slot = slots[currentWriteIndex]

    guard
      let microphoneFrameCount = downmix(
        buffers: buffers,
        range: 0..<tapIndex,
        expectedChannelCount: microphoneChannelCount,
        into: slot.microphone
      ),
      let systemFrameCount = downmix(
        buffers: buffers,
        range: tapIndex..<(tapIndex + 1),
        expectedChannelCount: tapChannelCount,
        into: slot.system
      )
    else {
      _ = oversizedChunks.add(1, ordering: .relaxed)
      return
    }

    slot.microphoneFrameCount = microphoneFrameCount
    slot.systemFrameCount = systemFrameCount
    slot.hostTime = inputTime.mHostTime
    lastValidInputHostTime.store(inputTime.mHostTime, ordering: .releasing)
    writeIndex.store(nextWriteIndex, ordering: .releasing)
  }

  /// Called only by the processing queue. Allocation is intentionally allowed
  /// here because this is no longer Core Audio's realtime thread.
  func pop() -> AggregateInputSnapshot? {
    let currentReadIndex = readIndex.load(ordering: .relaxed)
    guard currentReadIndex != writeIndex.load(ordering: .acquiring) else { return nil }
    let slot = slots[currentReadIndex]
    let snapshot = AggregateInputSnapshot(
      microphoneSamples: Array(
        UnsafeBufferPointer(
          start: slot.microphone,
          count: slot.microphoneFrameCount
        )
      ),
      systemSamples: Array(
        UnsafeBufferPointer(
          start: slot.system,
          count: slot.systemFrameCount
        )
      ),
      hostTime: slot.hostTime
    )
    readIndex.store((currentReadIndex + 1) % slots.count, ordering: .releasing)
    return snapshot
  }

  func stopAcceptingAudio() {
    accepting.store(false, ordering: .releasing)
  }

  private func downmix(
    buffers: UnsafeMutableAudioBufferListPointer,
    range: Range<Int>,
    expectedChannelCount: Int,
    into output: UnsafeMutablePointer<Float>
  ) -> Int? {
    var channelCount = 0
    var frameCount = 0
    for index in range {
      let buffer = buffers[index]
      let bufferChannelCount = Int(buffer.mNumberChannels)
      guard bufferChannelCount > 0, buffer.mData != nil else { continue }
      let sampleCount = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
      guard sampleCount >= bufferChannelCount else { return nil }
      channelCount += bufferChannelCount
      frameCount = max(frameCount, sampleCount / bufferChannelCount)
    }
    guard
      channelCount == expectedChannelCount,
      frameCount > 0,
      frameCount <= maximumFrameCount
    else { return nil }

    output.update(repeating: 0, count: frameCount)
    for index in range {
      let buffer = buffers[index]
      let bufferChannelCount = Int(buffer.mNumberChannels)
      guard
        bufferChannelCount > 0,
        let data = buffer.mData
      else { continue }
      let samples = data.assumingMemoryBound(to: Float.self)
      let bufferFrameCount =
        Int(buffer.mDataByteSize) / MemoryLayout<Float>.size / bufferChannelCount
      for frame in 0..<min(frameCount, bufferFrameCount) {
        let offset = frame * bufferChannelCount
        for channel in 0..<bufferChannelCount {
          output[frame] += samples[offset + channel]
        }
      }
    }
    let divisor = Float(channelCount)
    for frame in 0..<frameCount {
      output[frame] /= divisor
    }
    return frameCount
  }

  private func recordDroppedChunk(inputData: UnsafePointer<AudioBufferList>) {
    let buffers = UnsafeMutableAudioBufferListPointer(
      UnsafeMutablePointer(mutating: inputData)
    )
    let estimatedFrames = buffers.reduce(0) { result, buffer in
      let channels = max(1, Int(buffer.mNumberChannels))
      let samples = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
      return max(result, samples / channels)
    }
    _ = droppedChunks.add(1, ordering: .relaxed)
    _ = droppedFrames.add(estimatedFrames, ordering: .relaxed)
  }
}
