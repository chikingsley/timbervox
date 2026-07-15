import AppKit
import SwiftUI

struct ModeActivationSheet: View {
  @Binding var selectedBundleIdentifiers: [String]
  @State private var query = ""

  @Environment(\.scDismissSheet) private var dismissSheet
  @Environment(\.theme) private var theme

  var body: some View {
    SCSheetContent(showsCloseButton: false) {
      HStack(spacing: AppSpacing.md) {
        Button {
          dismissSheet()
        } label: {
          Image(systemName: "chevron.left")
        }
        .buttonStyle(.sc(.ghost, size: .iconSM))
        .accessibilityLabel("Close activate for apps")

        Spacer()
        SCSheetTitle("Activate for apps")
        Spacer()

        Color.clear.frame(width: 32, height: 32)
      }

      SCSheetDescription(
        "Add apps to automatically switch to this mode when you are using them."
      )

      SCInput("App name", text: $query, size: .sm)

      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          if query.isEmpty {
            sectionLabel("Categories")
            ForEach(ModeActivationCatalog.categories) { category in
              categoryRow(category)
            }
          }

          sectionLabel("Apps")
          ForEach(filteredApplications) { application in
            applicationRow(application)
          }
        }
        .padding(.vertical, AppSpacing.xs)
      }
      .frame(maxHeight: 360)
      .background(theme.popover, in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
          .strokeBorder(theme.border)
      }
    }
  }

  private var filteredApplications: [ModeActivationApplication] {
    guard !query.isEmpty else { return ModeActivationCatalog.installedApplications }
    return ModeActivationCatalog.installedApplications.filter {
      $0.name.localizedCaseInsensitiveContains(query)
        || $0.bundleIdentifier.localizedCaseInsensitiveContains(query)
    }
  }

  private func sectionLabel(_ label: String) -> some View {
    Text(label)
      .font(.caption)
      .foregroundStyle(theme.mutedForeground)
      .padding(.horizontal, AppSpacing.md)
      .padding(.top, AppSpacing.sm)
      .padding(.bottom, AppSpacing.xs)
  }

  private func categoryRow(_ category: ModeActivationCategory) -> some View {
    let installedBundleIdentifiers = category.bundleIdentifiers.filter {
      ModeActivationCatalog.installedBundleIdentifiers.contains($0)
    }
    let isSelected =
      !installedBundleIdentifiers.isEmpty
      && installedBundleIdentifiers.allSatisfy(selectedBundleIdentifiers.contains)

    return Button {
      if isSelected {
        selectedBundleIdentifiers.removeAll { installedBundleIdentifiers.contains($0) }
      } else {
        selectedBundleIdentifiers = Array(
          Set(selectedBundleIdentifiers + installedBundleIdentifiers)
        ).sorted()
      }
    } label: {
      HStack(spacing: AppSpacing.md) {
        Image(systemName: category.systemImage)
          .foregroundStyle(theme.mutedForeground)
          .frame(width: 18)
        Text(category.name)
          .font(.system(size: 14, weight: .semibold))
        Spacer()
        applicationIcons(for: installedBundleIdentifiers)
        if isSelected {
          Image(systemName: "checkmark")
            .font(.caption.weight(.semibold))
        }
      }
      .padding(.horizontal, AppSpacing.md)
      .frame(height: 32)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(installedBundleIdentifiers.isEmpty)
  }

  private func applicationRow(_ application: ModeActivationApplication) -> some View {
    let isSelected = selectedBundleIdentifiers.contains(application.bundleIdentifier)

    return Button {
      if isSelected {
        selectedBundleIdentifiers.removeAll { $0 == application.bundleIdentifier }
      } else {
        selectedBundleIdentifiers.append(application.bundleIdentifier)
      }
    } label: {
      HStack(spacing: AppSpacing.md) {
        ModeApplicationIcon(bundleIdentifier: application.bundleIdentifier, size: 20)
        Text(application.name)
          .font(.system(size: 14, weight: .semibold))
        Spacer()
        if isSelected {
          Image(systemName: "checkmark")
            .font(.caption.weight(.semibold))
        }
      }
      .padding(.horizontal, AppSpacing.md)
      .frame(height: 34)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func applicationIcons(for bundleIdentifiers: [String]) -> some View {
    HStack(spacing: 2) {
      ForEach(bundleIdentifiers.prefix(3), id: \.self) {
        ModeApplicationIcon(bundleIdentifier: $0, size: 18)
      }
    }
  }
}

private struct ModeActivationApplication: Identifiable {
  let name: String
  let bundleIdentifier: String

  var id: String { bundleIdentifier }
}

private struct ModeActivationCategory: Identifiable {
  let id: String
  let name: String
  let systemImage: String
  let bundleIdentifiers: [String]
}

private enum ModeActivationCatalog {
  static let candidates = [
    ModeActivationApplication(name: "Mail", bundleIdentifier: "com.apple.mail"),
    ModeActivationApplication(name: "Messages", bundleIdentifier: "com.apple.MobileSMS"),
    ModeActivationApplication(name: "ChatGPT", bundleIdentifier: "com.openai.chat"),
    ModeActivationApplication(name: "Claude", bundleIdentifier: "com.anthropic.claudefordesktop"),
    ModeActivationApplication(name: "Notes", bundleIdentifier: "com.apple.Notes"),
    ModeActivationApplication(name: "Pages", bundleIdentifier: "com.apple.iWork.Pages"),
    ModeActivationApplication(name: "Visual Studio Code", bundleIdentifier: "com.microsoft.VSCode"),
    ModeActivationApplication(name: "Codex", bundleIdentifier: "com.openai.codex"),
    ModeActivationApplication(name: "Terminal", bundleIdentifier: "com.apple.Terminal"),
    ModeActivationApplication(name: "Safari", bundleIdentifier: "com.apple.Safari"),
    ModeActivationApplication(name: "Discord", bundleIdentifier: "com.hnc.Discord"),
  ]

  static let categories = [
    ModeActivationCategory(
      id: "mail",
      name: "Mail",
      systemImage: "envelope",
      bundleIdentifiers: ["com.apple.mail"]
    ),
    ModeActivationCategory(
      id: "messaging",
      name: "Messaging",
      systemImage: "message",
      bundleIdentifiers: ["com.apple.MobileSMS", "com.hnc.Discord"]
    ),
    ModeActivationCategory(
      id: "ai-chat",
      name: "AI chat",
      systemImage: "sparkles",
      bundleIdentifiers: ["com.openai.chat", "com.anthropic.claudefordesktop"]
    ),
    ModeActivationCategory(
      id: "text-editing",
      name: "Text editing",
      systemImage: "doc.text",
      bundleIdentifiers: ["com.apple.Notes", "com.apple.iWork.Pages"]
    ),
    ModeActivationCategory(
      id: "coding",
      name: "Coding",
      systemImage: "chevron.left.forwardslash.chevron.right",
      bundleIdentifiers: ["com.microsoft.VSCode", "com.openai.codex"]
    ),
    ModeActivationCategory(
      id: "terminal",
      name: "Terminal",
      systemImage: "terminal",
      bundleIdentifiers: ["com.apple.Terminal"]
    ),
    ModeActivationCategory(
      id: "browsers",
      name: "Browsers",
      systemImage: "globe",
      bundleIdentifiers: ["com.apple.Safari"]
    ),
  ]

  @MainActor static let installedApplications = candidates.filter {
    NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleIdentifier) != nil
  }

  @MainActor static let installedBundleIdentifiers = Set(
    installedApplications.map(\.bundleIdentifier)
  )
}

private struct ModeApplicationIcon: View {
  let bundleIdentifier: String
  let size: CGFloat

  @Environment(\.theme) private var theme

  @MainActor private static let iconCache = NSCache<NSString, NSImage>()

  var body: some View {
    Group {
      if let image = Self.applicationIcon(bundleIdentifier: bundleIdentifier) {
        Image(nsImage: image)
          .resizable()
          .scaledToFit()
      } else {
        Image(systemName: "app")
          .font(.system(size: size * 0.55))
          .foregroundStyle(theme.mutedForeground)
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
    .accessibilityHidden(true)
  }

  @MainActor
  private static func applicationIcon(bundleIdentifier: String) -> NSImage? {
    let cacheKey = bundleIdentifier as NSString
    if let cached = iconCache.object(forKey: cacheKey) { return cached }
    guard
      let applicationURL = NSWorkspace.shared.urlForApplication(
        withBundleIdentifier: bundleIdentifier
      )
    else { return nil }
    let icon = NSWorkspace.shared.icon(forFile: applicationURL.path)
    iconCache.setObject(icon, forKey: cacheKey)
    return icon
  }
}
