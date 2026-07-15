import AppKit
import SwiftUI

struct HistorySourceApplicationIcon: View {
  let record: TranscriptRecord
  let size: CGFloat
  @Environment(\.theme) private var theme

  @MainActor private static let iconCache = NSCache<NSString, NSImage>()

  var body: some View {
    Group {
      if let image = Self.applicationIcon(bundleIdentifier: record.sourceApplicationBundleIdentifier) {
        Image(nsImage: image)
          .resizable()
          .scaledToFit()
      } else {
        Image(systemName: record.modeID == nil ? "waveform" : "mic")
          .font(.system(size: size * 0.45, weight: .medium))
          .foregroundStyle(theme.mutedForeground)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(theme.background.opacity(0.7))
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
    .accessibilityHidden(true)
  }

  @MainActor
  private static func applicationIcon(bundleIdentifier: String?) -> NSImage? {
    guard let bundleIdentifier else { return nil }
    let cacheKey = bundleIdentifier as NSString
    if let cached = iconCache.object(forKey: cacheKey) { return cached }
    guard
      let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    else { return nil }
    let icon = NSWorkspace.shared.icon(forFile: applicationURL.path)
    iconCache.setObject(icon, forKey: cacheKey)
    return icon
  }
}
