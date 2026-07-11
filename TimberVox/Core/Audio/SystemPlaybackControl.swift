import AppKit
import AudioToolbox
import CoreAudio
import Foundation

/// The playback mechanisms a `PlaybackPolicyCoordinator` drives. Live code
/// talks to real hardware and applications; tests inject a recorder.
protocol PlaybackControlling: Sendable {
  func outputVolume() -> Float?
  func setOutputVolume(_ volume: Float)
  func isAudioPlayingOnDefaultOutput() -> Bool
  func pauseKnownMediaPlayers() -> [String]
  func resumeMediaPlayers(_ players: [String])
  func sendMediaPlayPauseKey() -> Bool
}

/// Ported from the proven old-app implementation. Volume changes use the
/// public Core Audio virtual main volume, which does not affect the
/// system-audio process tap. Pause is best-effort without the private
/// MediaRemote framework: script the known players, then fall back to a
/// synthesized media key only while audio is verifiably playing.
struct SystemPlaybackControl: PlaybackControlling {
  private static let scriptablePlayers: [(name: String, bundleID: String)] = [
    ("Music", "com.apple.Music"),
    ("Spotify", "com.spotify.client"),
    ("VLC", "org.videolan.vlc"),
  ]

  private let logger = TimberVoxLog.audio

  func outputVolume() -> Float? {
    guard let deviceID = defaultOutputDevice() else { return nil }
    var volume: Float32 = 0
    var size = UInt32(MemoryLayout<Float32>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )
    guard AudioObjectHasProperty(deviceID, &address) else { return nil }
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
    guard status == noErr else {
      logger.error("Reading output volume failed: \(status)")
      return nil
    }
    return volume
  }

  func setOutputVolume(_ volume: Float) {
    guard let deviceID = defaultOutputDevice() else { return }
    var newVolume = Float32(volume)
    let size = UInt32(MemoryLayout<Float32>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &newVolume)
    if status != noErr {
      logger.error("Setting output volume failed: \(status)")
    }
  }

  func isAudioPlayingOnDefaultOutput() -> Bool {
    guard let deviceID = defaultOutputDevice() else { return false }
    var isRunning: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &isRunning)
    return status == noErr && isRunning != 0
  }

  func pauseKnownMediaPlayers() -> [String] {
    let installed = Self.scriptablePlayers.filter {
      NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleID) != nil
    }
    guard !installed.isEmpty else { return [] }

    var scriptParts = ["set pausedPlayers to {}"]
    for player in installed {
      scriptParts.append(Self.pauseScript(for: player.name))
    }
    scriptParts.append("return pausedPlayers")

    guard let result = runAppleScript(scriptParts.joined(separator: "\n\n")) else { return [] }
    var paused: [String] = []
    if result.numberOfItems > 0 {
      for index in 1...result.numberOfItems {
        if let name = result.atIndex(index)?.stringValue {
          paused.append(name)
        }
      }
    }
    if !paused.isEmpty {
      logger.notice("Paused media players: \(paused.joined(separator: ", "))")
    }
    return paused
  }

  func resumeMediaPlayers(_ players: [String]) {
    let known = players.filter { name in Self.scriptablePlayers.contains { $0.name == name } }
    guard !known.isEmpty else { return }
    let scriptParts = known.map { name in
      """
      try
        if application "\(name)" is running then
          tell application "\(name)" to play
        end if
      end try
      """
    }
    _ = runAppleScript(scriptParts.joined(separator: "\n\n"))
    logger.notice("Resumed media players: \(known.joined(separator: ", "))")
  }

  func sendMediaPlayPauseKey() -> Bool {
    guard CGPreflightPostEventAccess() else {
      logger.notice("Skipping media key: event posting permission is not granted")
      return false
    }
    postMediaPlayPauseKey(down: true)
    postMediaPlayPauseKey(down: false)
    logger.notice("Sent media play/pause key")
    return true
  }

  private func postMediaPlayPauseKey(down: Bool) {
    let nxKeyTypePlay: UInt32 = 16
    let flags = NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00)
    let data1 = Int((nxKeyTypePlay << 16) | (down ? 0xA << 8 : 0xB << 8))
    let event = NSEvent.otherEvent(
      with: .systemDefined,
      location: .zero,
      modifierFlags: flags,
      timestamp: 0,
      windowNumber: 0,
      context: nil,
      subtype: 8,
      data1: data1,
      data2: -1
    )
    event?.cgEvent?.post(tap: .cghidEventTap)
  }

  private func runAppleScript(_ source: String) -> NSAppleEventDescriptor? {
    var error: NSDictionary?
    let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
    if let error {
      logger.error("Media player script failed: \(error)")
      return nil
    }
    return result
  }

  private func defaultOutputDevice() -> AudioDeviceID? {
    var deviceID = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      &size,
      &deviceID
    )
    guard status == noErr else {
      logger.error("Reading default output device failed: \(status)")
      return nil
    }
    return deviceID
  }

  private static func pauseScript(for appName: String) -> String {
    if appName == "VLC" {
      return """
        try
          if application "VLC" is running then
            tell application "VLC"
              if playing then
                pause
                set end of pausedPlayers to "VLC"
              end if
            end tell
          end if
        end try
        """
    }
    return """
      try
        if application "\(appName)" is running then
          tell application "\(appName)"
            if player state is playing then
              pause
              set end of pausedPlayers to "\(appName)"
            end if
          end tell
        end if
      end try
      """
  }
}
