import SwiftUI

struct AppDownloadStatusBar: View {
  let onOpenModes: () -> Void

  @State private var packageStore = FluidAudioModelPackageStore.shared
  @State private var catalog = TranscriptionModelCatalogStore.shared
  @Environment(\.theme) private var theme

  var body: some View {
    if showsStatus {
      HStack(spacing: AppSpacing.md) {
        statusIcon

        VStack(alignment: .leading, spacing: AppSpacing.xs) {
          Text(statusLabel)
            .font(.caption.weight(.semibold))
            .lineLimit(1)

          if isDownloading {
            HStack(spacing: AppSpacing.sm) {
              ProgressView(value: combinedProgress)
                .progressViewStyle(.scLinear)
              Text(Self.percentage(combinedProgress))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(theme.mutedForeground)
                .frame(width: 34, alignment: .trailing)
            }
          } else if let completionDetail {
            Text(completionDetail)
              .font(.caption2)
              .foregroundStyle(theme.mutedForeground)
              .lineLimit(1)
          }
        }

        Spacer(minLength: AppSpacing.md)

        Button("View in Modes") {
          onOpenModes()
          packageStore.dismissDownloadResults()
        }
        .buttonStyle(.sc(.ghost, size: .xs))

        if !isDownloading {
          Button {
            packageStore.dismissDownloadResults()
          } label: {
            Image(systemName: "xmark")
          }
          .buttonStyle(.sc(.ghost, size: .iconXS))
          .accessibilityLabel("Dismiss model download status")
        }
      }
      .padding(.horizontal, AppSpacing.lg)
      .padding(.vertical, AppSpacing.sm)
      .frame(maxWidth: .infinity, alignment: .leading)
      .foregroundStyle(theme.foreground)
      .background(theme.background)
      .overlay(alignment: .top) { SCSeparator() }
      .accessibilityElement(children: .contain)
      .task(id: completionIdentity) {
        guard isSuccessfulCompletion else { return }
        try? await Task.sleep(for: .seconds(8))
        guard !Task.isCancelled else { return }
        packageStore.dismissDownloadResults()
      }
    }
  }

  @ViewBuilder private var statusIcon: some View {
    if isDownloading {
      SCSpinner(size: 14, lineWidth: 1.5)
        .frame(width: 18, height: 18)
    } else if hasFailure {
      Image(systemName: "exclamationmark.circle.fill")
        .foregroundStyle(theme.destructive)
        .frame(width: 18, height: 18)
    } else {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(theme.foreground)
        .frame(width: 18, height: 18)
    }
  }

  private var showsStatus: Bool {
    isDownloading || !packageStore.recentDownloadResults.isEmpty
  }

  private var isDownloading: Bool {
    !packageStore.activeDownloads.isEmpty
  }

  private var combinedProgress: Double {
    let downloads = packageStore.activeDownloads
    guard !downloads.isEmpty else { return 0 }
    let completedBytes = downloads.map(\.progress.estimatedCompletedBytes).reduce(0, +)
    let totalBytes = downloads.map(\.progress.estimatedTotalBytes).reduce(0, +)
    guard totalBytes > 0 else { return 0 }
    return Double(completedBytes) / Double(totalBytes)
  }

  private var statusLabel: String {
    let downloads = packageStore.activeDownloads
    if downloads.count == 1, let download = downloads.first {
      let name = catalog.models.first { $0.id == download.modelID }?.displayName ?? "model"
      return "Downloading \(name) · \(Self.byteProgress(download.progress))"
    }
    if downloads.count > 1 {
      let completedBytes = downloads.map(\.progress.estimatedCompletedBytes).reduce(0, +)
      let totalBytes = downloads.map(\.progress.estimatedTotalBytes).reduce(0, +)
      return
        "Downloading \(downloads.count) models · \(Self.byteProgress(completed: completedBytes, total: totalBytes))"
    }

    let results = packageStore.recentDownloadResults
    let failures = results.filter { result in
      if case .failed = result.outcome { return true }
      return false
    }
    if !failures.isEmpty {
      return failures.count == 1 ? "Model download failed" : "\(failures.count) model downloads failed"
    }
    if results.count == 1, let result = results.first {
      return "\(modelName(result.modelID)) is ready"
    }
    return "\(results.count) models are ready"
  }

  private var completionDetail: String? {
    guard !isDownloading else { return nil }
    for result in packageStore.recentDownloadResults {
      if case .failed(let message) = result.outcome {
        return message
      }
    }
    return "Available for local transcription."
  }

  private var hasFailure: Bool {
    packageStore.recentDownloadResults.contains { result in
      if case .failed = result.outcome { return true }
      return false
    }
  }

  private var isSuccessfulCompletion: Bool {
    !packageStore.recentDownloadResults.isEmpty && !hasFailure && !isDownloading
  }

  private var completionIdentity: String {
    packageStore.recentDownloadResults.map { result in
      switch result.outcome {
      case .failed(let message): "\(result.modelID):failed:\(message)"
      case .ready: "\(result.modelID):ready"
      }
    }
    .joined(separator: "|")
  }

  private func modelName(_ modelID: String) -> String {
    catalog.models.first { $0.id == modelID }?.displayName ?? "Model"
  }

  private static func percentage(_ progress: Double) -> String {
    "\(Int((min(max(progress, 0), 1) * 100).rounded()))%"
  }

  private static func byteProgress(_ progress: FluidAudioModelPackageProgress) -> String {
    byteProgress(
      completed: progress.estimatedCompletedBytes,
      total: progress.estimatedTotalBytes
    )
  }

  private static func byteProgress(completed: Int64, total: Int64) -> String {
    let completedLabel = ByteCountFormatter.string(fromByteCount: completed, countStyle: .file)
    let totalLabel = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    return "about \(completedLabel) of \(totalLabel)"
  }
}
