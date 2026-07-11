import AudioToolbox
import CoreAudio
import Foundation

enum SystemAudioPermissionEvidence {
  static let successfulCaptureKey = "systemAudioCaptureHasSucceeded"
}

enum AggregateAudioRecorderError: LocalizedError {
  case captureStopped
  case conversionFailed
  case coreAudio(String, OSStatus)
  case invalidConfiguration

  var errorDescription: String? {
    switch self {
    case .captureStopped:
      "Microphone and system-audio capture stopped unexpectedly."
    case .conversionFailed:
      "Microphone and system audio could not be converted."
    case .coreAudio(let operation, let status):
      "\(operation) failed with Core Audio status \(status)."
    case .invalidConfiguration:
      "The microphone and system-audio capture configuration is invalid."
    }
  }
}

extension AudioObjectID {
  func aggregateBufferFrameSizes() throws -> (current: Int, maximum: Int) {
    var currentAddress = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyBufferFrameSize,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var currentFrames = UInt32.zero
    var currentSize = UInt32(MemoryLayout<UInt32>.size)
    let currentStatus = AudioObjectGetPropertyData(
      self,
      &currentAddress,
      0,
      nil,
      &currentSize,
      &currentFrames
    )
    guard currentStatus == noErr else {
      throw AggregateAudioRecorderError.coreAudio(
        "Read aggregate audio buffer frame size",
        currentStatus
      )
    }

    var rangeAddress = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyBufferFrameSizeRange,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var range = AudioValueRange()
    var rangeSize = UInt32(MemoryLayout<AudioValueRange>.size)
    let rangeStatus = AudioObjectGetPropertyData(
      self,
      &rangeAddress,
      0,
      nil,
      &rangeSize,
      &range
    )
    guard rangeStatus == noErr else {
      throw AggregateAudioRecorderError.coreAudio(
        "Read aggregate audio buffer frame-size range",
        rangeStatus
      )
    }
    return (
      Int(currentFrames),
      Swift.max(Int(currentFrames), Int(ceil(range.mMaximum)))
    )
  }

  var isAggregateKnown: Bool {
    self != AudioObjectID(kAudioObjectUnknown)
  }

  static func aggregateDefaultInputDevice() throws -> AudioDeviceID {
    try AudioObjectID(kAudioObjectSystemObject).readAggregateProperty(
      selector: kAudioHardwarePropertyDefaultInputDevice,
      scope: kAudioObjectPropertyScopeGlobal,
      defaultValue: AudioDeviceID(kAudioObjectUnknown)
    )
  }

  func aggregateDeviceUID() throws -> String {
    try readAggregateProperty(
      selector: kAudioDevicePropertyDeviceUID,
      scope: kAudioObjectPropertyScopeGlobal,
      defaultValue: "" as CFString
    ) as String
  }

  func aggregateTapStreamBasicDescription() throws -> AudioStreamBasicDescription {
    try readAggregateProperty(
      selector: kAudioTapPropertyFormat,
      scope: kAudioObjectPropertyScopeGlobal,
      defaultValue: AudioStreamBasicDescription()
    )
  }

  func inputChannelCount() throws -> Int {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreamConfiguration,
      mScope: kAudioDevicePropertyScopeInput,
      mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    var status = AudioObjectGetPropertyDataSize(self, &address, 0, nil, &size)
    guard status == noErr else {
      throw AggregateAudioRecorderError.coreAudio(
        "Read microphone input configuration size",
        status
      )
    }
    let rawPointer = UnsafeMutableRawPointer.allocate(
      byteCount: Int(size),
      alignment: MemoryLayout<AudioBufferList>.alignment
    )
    defer { rawPointer.deallocate() }
    status = AudioObjectGetPropertyData(self, &address, 0, nil, &size, rawPointer)
    guard status == noErr else {
      throw AggregateAudioRecorderError.coreAudio(
        "Read microphone input configuration",
        status
      )
    }
    return UnsafeMutableAudioBufferListPointer(
      rawPointer.assumingMemoryBound(to: AudioBufferList.self)
    ).reduce(0) { $0 + Int($1.mNumberChannels) }
  }

  func readAggregateProperty<T>(
    selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope,
    defaultValue: T
  ) throws -> T {
    var address = AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: scope,
      mElement: kAudioObjectPropertyElementMain
    )
    var size = UInt32(MemoryLayout<T>.size)
    var value = defaultValue
    let status = withUnsafeMutablePointer(to: &value) { pointer in
      AudioObjectGetPropertyData(self, &address, 0, nil, &size, pointer)
    }
    guard status == noErr else {
      throw AggregateAudioRecorderError.coreAudio("Read Core Audio property", status)
    }
    return value
  }
}
