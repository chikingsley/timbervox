import os

enum TimberVoxLog {
  private static let subsystem = "com.chiejimofor.timbervox"

  static let dictation = Logger(subsystem: subsystem, category: "dictation")
  static let audio = Logger(subsystem: subsystem, category: "audio")
  static let hotkeys = Logger(subsystem: subsystem, category: "hotkeys")
}
