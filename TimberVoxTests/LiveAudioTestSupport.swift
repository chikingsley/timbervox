@preconcurrency import AVFoundation
import CoreAudio
import XCTest

/// Shared gating and signal helpers for the live macOS audio acceptance tests.
enum LiveAudioTest {
  static func requireLiveCapture() throws {
    try requireMarker(
      environmentKey: "TIMBERVOX_LIVE_AUDIO_CAPTURE",
      markerPath: "/tmp/timbervox-live-audio-capture",
      purpose: "live macOS capture"
    )
  }

  static func requireProviderAcceptance() throws {
    try requireMarker(
      environmentKey: "TIMBERVOX_LIVE_PROVIDER_ACCEPTANCE",
      markerPath: "/tmp/timbervox-live-provider-acceptance",
      purpose: "live provider acceptance"
    )
  }

  static func requireDualSpeech() throws {
    try requireMarker(
      environmentKey: "TIMBERVOX_DUAL_SPEECH",
      markerPath: "/tmp/timbervox-dual-speech",
      purpose: "the human-in-the-loop dual-speech acceptance"
    )
  }

  static func requirePauseAcceptance() throws {
    try requireMarker(
      environmentKey: "TIMBERVOX_PAUSE_ACCEPTANCE",
      markerPath: "/tmp/timbervox-pause-acceptance",
      purpose: "the pause-policy acceptance with a real media player"
    )
  }

  static func requireEndurance() throws {
    try requireMarker(
      environmentKey: "TIMBERVOX_ENDURANCE",
      markerPath: "/tmp/timbervox-endurance",
      purpose: "the ten-minute capture endurance run"
    )
  }

  static func outputDeviceIDs() -> [AudioDeviceID] {
    var address = systemProperty(kAudioHardwarePropertyDevices)
    var size: UInt32 = 0
    let system = AudioObjectID(kAudioObjectSystemObject)
    guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
    var devices = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &devices) == noErr else { return [] }
    return devices.filter(hasOutputStreams)
  }

  static func defaultOutputDeviceID() -> AudioDeviceID? {
    var address = systemProperty(kAudioHardwarePropertyDefaultOutputDevice)
    var deviceID = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let system = AudioObjectID(kAudioObjectSystemObject)
    let status = AudioObjectGetPropertyData(system, &address, 0, nil, &size, &deviceID)
    return status == noErr ? deviceID : nil
  }

  static func setDefaultOutputDevice(_ deviceID: AudioDeviceID) {
    var address = systemProperty(kAudioHardwarePropertyDefaultOutputDevice)
    var newDevice = deviceID
    let size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let system = AudioObjectID(kAudioObjectSystemObject)
    _ = AudioObjectSetPropertyData(system, &address, 0, nil, size, &newDevice)
  }

  /// Physical memory footprint of this process in bytes.
  static func physicalFootprint() -> Double? {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
    )
    let result = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    guard result == KERN_SUCCESS else { return nil }
    return Double(info.phys_footprint)
  }

  private static func hasOutputStreams(_ device: AudioDeviceID) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreams,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr else { return false }
    return size > 0
  }

  private static func systemProperty(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
  }

  static func startQuickTimePlaying(_ url: URL) throws {
    _ = try runProcess(
      "/usr/bin/osascript",
      arguments: [
        "-e", "tell application \"QuickTime Player\"",
        "-e", "open POSIX file \"\(url.path)\"",
        "-e", "play document 1",
        "-e", "end tell",
      ]
    )
  }

  static func quitQuickTime() {
    _ = try? runProcess(
      "/usr/bin/osascript",
      arguments: ["-e", "tell application \"QuickTime Player\" to quit saving no"]
    )
  }

  /// Goertzel power of the tone within a window of seconds into the samples.
  static func tonePower(
    in samples: [Float],
    seconds window: ClosedRange<Double>,
    sampleRate: Double,
    frequency: Double = 880
  ) -> Double {
    let start = max(0, min(samples.count, Int(window.lowerBound * sampleRate)))
    let end = max(start, min(samples.count, Int(window.upperBound * sampleRate)))
    guard end > start else { return 0 }
    return power(of: Array(samples[start..<end]), atHertz: frequency, sampleRate: sampleRate)
  }

  static func makeArtifactsDirectory(named name: String) throws -> URL {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    let directory = URL(fileURLWithPath: "/tmp/timbervox-acceptance")
      .appendingPathComponent("\(formatter.string(from: .now))-\(name)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  static func writeTone(to url: URL, frequency: Double, seconds: Double = 1) throws {
    let sampleRate = 48_000.0
    let frameCount = AVAudioFrameCount(sampleRate * seconds)
    guard
      let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: sampleRate,
        channels: 1,
        interleaved: false
      ),
      let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
      let samples = buffer.floatChannelData?[0]
    else {
      throw LiveAudioTestError.toneGenerationFailed
    }
    buffer.frameLength = buffer.frameCapacity
    for index in 0..<Int(buffer.frameLength) {
      samples[index] = Float(sin(2 * Double.pi * frequency * Double(index) / sampleRate) * 0.2)
    }
    let file = try AVAudioFile(
      forWriting: url,
      settings: format.settings,
      commonFormat: .pcmFormatFloat32,
      interleaved: false
    )
    try file.write(from: buffer)
  }

  /// Renders a spoken phrase with the system voice and returns its duration.
  static func writeSpokenPhrase(_ phrase: String, to url: URL) throws -> TimeInterval {
    _ = try runProcess("/usr/bin/say", arguments: ["-o", url.path, phrase])
    let file = try AVAudioFile(forReading: url)
    return Double(file.length) / file.processingFormat.sampleRate
  }

  private static func runProcess(_ path: String, arguments: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw LiveAudioTestError.processFailed(path, Int(process.terminationStatus))
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
  }

  static func systemOutputVolume() throws -> Int {
    let output = try runProcess(
      "/usr/bin/osascript",
      arguments: ["-e", "output volume of (get volume settings)"]
    )
    guard let volume = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      throw LiveAudioTestError.volumeReadFailed
    }
    return volume
  }

  static func setSystemOutputVolume(_ volume: Int) throws {
    _ = try runProcess(
      "/usr/bin/osascript",
      arguments: ["-e", "set volume output volume \(volume)"]
    )
  }

  /// Speaks an audible instruction to the human tester at a usable volume.
  static func speakCue(_ cue: String, atVolume volume: Int) throws {
    try setSystemOutputVolume(volume)
    _ = try runProcess("/usr/bin/say", arguments: [cue])
  }

  static func samples(at url: URL) throws -> [Float] {
    let file = try AVAudioFile(forReading: url)
    guard
      let buffer = AVAudioPCMBuffer(
        pcmFormat: file.processingFormat,
        frameCapacity: AVAudioFrameCount(file.length)
      )
    else {
      throw LiveAudioTestError.sampleReadFailed(url)
    }
    try file.read(into: buffer)
    guard let data = buffer.floatChannelData?[0] else {
      throw LiveAudioTestError.sampleReadFailed(url)
    }
    return Array(UnsafeBufferPointer(start: data, count: Int(buffer.frameLength)))
  }

  /// Goertzel power of one frequency, normalized by sample count.
  static func power(of samples: [Float], atHertz frequency: Double, sampleRate: Double) -> Double {
    let normalized = 2 * Double.pi * frequency / sampleRate
    let coefficient = 2 * cos(normalized)
    var previous = 0.0
    var beforePrevious = 0.0
    for sample in samples {
      let current = Double(sample) + coefficient * previous - beforePrevious
      beforePrevious = previous
      previous = current
    }
    let power = previous * previous + beforePrevious * beforePrevious
    return (power - coefficient * previous * beforePrevious) / Double(max(samples.count, 1))
  }

  static func rootMeanSquare(_ samples: [Float]) -> Double {
    guard !samples.isEmpty else { return 0 }
    let sum = samples.reduce(Double.zero) { $0 + Double($1) * Double($1) }
    return (sum / Double(samples.count)).squareRoot()
  }

  static func matchedKeywords(_ keywords: [String], in transcript: String) -> [String] {
    let lowered = transcript.lowercased()
    return keywords.filter { lowered.contains($0) }
  }

  private static func requireMarker(
    environmentKey: String,
    markerPath: String,
    purpose: String
  ) throws {
    let requested =
      ProcessInfo.processInfo.environment[environmentKey] == "1"
      || FileManager.default.fileExists(atPath: markerPath)
    guard requested else {
      throw XCTSkip("Set \(environmentKey)=1 or touch \(markerPath) to run \(purpose).")
    }
  }
}

enum LiveAudioTestError: Error {
  case toneGenerationFailed
  case processFailed(String, Int)
  case sampleReadFailed(URL)
  case volumeReadFailed
}
