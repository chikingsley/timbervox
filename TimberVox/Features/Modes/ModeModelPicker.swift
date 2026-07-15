import SwiftUI

struct ModeVoiceModelPicker: View {
  @Binding var selection: String?
  let models: [TranscriptionModelSpec]

  @State private var packageStore = FluidAudioModelPackageStore.shared
  @State private var preferences = ModeModelPreferenceStore.shared

  var body: some View {
    SCCombobox(
      selection: $selection,
      options: options,
      placeholder: "Choose a model",
      searchPlaceholder: "Search models",
      contentWidth: ModeLayout.modelPopoverWidth,
      contentMaxHeight: 326,
      selectsOnRowTap: false,
      trigger: { selected, expanded in
        let model = selected.first.flatMap(model(for:))
        ModeComboboxTrigger(
          title: model?.displayName ?? "Choose a model",
          isExpanded: expanded
        ) {
          if let model {
            ModeProviderTile(provider: model.provider, runtime: model.runtime, size: 20)
          }
        }
      },
      row: { option, _, select in
        if let model = model(for: option) {
          modelRow(model, select: select)
        }
      },
      groupHeader: { Text($0) },
      empty: { Text("No models found.") }
    )
    .task { await packageStore.refreshAll() }
  }

  private var options: [SCComboboxOption<String>] {
    let ordered = models.sorted { left, right in
      let leftFavorite = preferences.isFavorite(left.id)
      let rightFavorite = preferences.isFavorite(right.id)
      if leftFavorite != rightFavorite { return leftFavorite }
      return left.displayName.localizedCaseInsensitiveCompare(right.displayName) == .orderedAscending
    }
    return ordered.map {
      SCComboboxOption(
        value: $0.id,
        label: $0.displayName,
        keywords: [$0.provider, $0.runtime.label, $0.technicalName ?? ""],
        group: preferences.isFavorite($0.id) ? "Favorites" : "Models"
      )
    }
  }

  private func model(for option: SCComboboxOption<String>) -> TranscriptionModelSpec? {
    models.first { $0.id == option.value }
  }

  private func modelRow(
    _ model: TranscriptionModelSpec,
    select: SCComboboxSelectionAction
  ) -> some View {
    let packageState = packageStore.state(for: model.id)
    let packageBytes = packageStore.installedBytes(for: model.id)
    return HStack(spacing: 9) {
      SCComboboxRowAction(
        accessibilityLabel: modelAccessibilityLabel(
          model,
          packageState: packageState,
          packageBytes: packageBytes
        )
      ) {
        select()
      } label: {
        HStack(spacing: 9) {
          ModeProviderTile(provider: model.provider, runtime: model.runtime, size: 20)
          VStack(alignment: .leading, spacing: 1) {
            Text(model.displayName)
              .font(.system(size: 13))
              .lineLimit(1)
            if let metricLabel = model.presentation.metricLabel {
              Text(metricLabel)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            if model.runtime == .local {
              packageStatus(packageState, installedBytes: packageBytes)
            }
          }
          Spacer(minLength: 6)
        }
        .contentShape(Rectangle())
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      favoriteButton(modelID: model.id)
      if model.runtime == .local {
        packageButton(model)
      } else {
        Image(systemName: "cloud")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .frame(width: 24, height: 24)
          .accessibilityLabel("Cloud model")
      }
    }
    .frame(minHeight: model.runtime == .local ? 48 : model.presentation.metricLabel == nil ? 20 : 34)
  }

  private func favoriteButton(modelID: String) -> some View {
    let favorite = preferences.isFavorite(modelID)
    return SCComboboxRowAction(
      accessibilityLabel: favorite ? "Remove favorite" : "Add favorite"
    ) {
      preferences.toggleFavorite(modelID)
    } label: {
      Image(systemName: favorite ? "star.fill" : "star")
        .font(.system(size: 11))
        .foregroundStyle(favorite ? .primary : .secondary)
        .frame(width: 24, height: 24)
        .contentShape(Circle())
    }
  }

  @ViewBuilder
  private func packageButton(_ model: TranscriptionModelSpec) -> some View {
    let state = packageStore.state(for: model.id)
    SCComboboxRowAction(
      accessibilityLabel: state.actionLabel,
      isDisabled: state.isBusy
    ) {
      Task { await togglePackage(modelID: model.id, state: state) }
    } label: {
      Group {
        switch state {
        case .checking, .downloading:
          SCSpinner(size: 12, lineWidth: 1.5)
        case .ready:
          Image(systemName: "trash")
            .font(.system(size: 11))
        case .downloaded:
          Image(systemName: "checkmark.circle")
            .font(.system(size: 12))
        case .failed:
          Image(systemName: "exclamationmark.arrow.circlepath")
            .font(.system(size: 12))
        case .notDownloaded, .partial:
          Image(systemName: "arrow.down.circle")
            .font(.system(size: 12))
        case .unknown:
          Image(systemName: "questionmark.circle")
            .font(.system(size: 12))
        }
      }
      .foregroundStyle(.secondary)
      .frame(width: 24, height: 24)
      .contentShape(Circle())
    }
  }

  private func togglePackage(modelID: String, state: FluidAudioModelPackageState) async {
    switch state {
    case .checking, .downloading:
      return
    case .ready:
      await packageStore.delete(modelID: modelID)
    case .downloaded, .failed, .notDownloaded, .partial, .unknown:
      await packageStore.download(modelID: modelID)
    }
  }

  @ViewBuilder
  private func packageStatus(
    _ state: FluidAudioModelPackageState,
    installedBytes: Int64
  ) -> some View {
    HStack(spacing: 6) {
      Text(state.statusLabel(installedBytes: installedBytes))
        .font(.system(size: 10))
        .foregroundStyle(state.isFailure ? Color.red : .secondary)
        .lineLimit(1)
      if case .downloading(let progress) = state {
        ProgressView(value: progress)
          .progressViewStyle(.scLinear)
          .frame(width: 48)
      }
    }
  }

  private func modelAccessibilityLabel(
    _ model: TranscriptionModelSpec,
    packageState: FluidAudioModelPackageState,
    packageBytes: Int64
  ) -> String {
    var parts = [model.displayName]
    if let metricLabel = model.presentation.metricLabel {
      parts.append(metricLabel)
    }
    if model.runtime == .local {
      parts.append(packageState.statusLabel(installedBytes: packageBytes))
    }
    return parts.joined(separator: ", ")
  }
}

struct ModeLanguageModelPicker: View {
  @Binding var selection: String?
  let models: [CatalogModel]

  @State private var preferences = ModeModelPreferenceStore.shared

  var body: some View {
    SCCombobox(
      selection: $selection,
      options: options,
      placeholder: "Choose a model",
      searchPlaceholder: "Search models",
      contentWidth: ModeLayout.modelPopoverWidth,
      contentMaxHeight: 240,
      selectsOnRowTap: false,
      trigger: { selected, expanded in
        let model = selected.first.flatMap(model(for:))
        ModeComboboxTrigger(
          title: model?.displayName ?? "Choose a model",
          isExpanded: expanded
        ) {
          if let model {
            ModeProviderTile(provider: logoProvider(for: model), runtime: .cloud, size: 20)
          }
        }
      },
      row: { option, _, select in
        if let model = model(for: option) {
          modelRow(model, select: select)
        }
      },
      groupHeader: { Text($0) },
      empty: { Text("No models found.") }
    )
  }

  private var options: [SCComboboxOption<String>] {
    let ordered = models.sorted { left, right in
      let leftFavorite = preferences.isFavorite(left.id)
      let rightFavorite = preferences.isFavorite(right.id)
      if leftFavorite != rightFavorite { return leftFavorite }
      return left.displayName.localizedCaseInsensitiveCompare(right.displayName) == .orderedAscending
    }
    return ordered.map {
      SCComboboxOption(
        value: $0.id,
        label: $0.displayName,
        keywords: [$0.provider, $0.upstreamModel],
        group: preferences.isFavorite($0.id) ? "Favorites" : "Models"
      )
    }
  }

  private func model(for option: SCComboboxOption<String>) -> CatalogModel? {
    models.first { $0.id == option.value }
  }

  private func favoriteButton(modelID: String) -> some View {
    let favorite = preferences.isFavorite(modelID)
    return SCComboboxRowAction(
      accessibilityLabel: favorite ? "Remove favorite" : "Add favorite"
    ) {
      preferences.toggleFavorite(modelID)
    } label: {
      Image(systemName: favorite ? "star.fill" : "star")
        .font(.system(size: 11))
        .foregroundStyle(favorite ? .primary : .secondary)
        .frame(width: 24, height: 24)
        .contentShape(Circle())
    }
  }

  private func modelRow(
    _ model: CatalogModel,
    select: SCComboboxSelectionAction
  ) -> some View {
    HStack(spacing: 9) {
      SCComboboxRowAction(
        accessibilityLabel: [model.displayName, model.presentationLabel]
          .compactMap { $0 }
          .joined(separator: ", ")
      ) {
        select()
      } label: {
        HStack(spacing: 9) {
          ModeProviderTile(provider: logoProvider(for: model), runtime: .cloud, size: 20)
          VStack(alignment: .leading, spacing: 1) {
            Text(model.displayName)
              .font(.system(size: 13))
              .lineLimit(1)
            if let presentationLabel = model.presentationLabel {
              Text(presentationLabel)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
          }
          Spacer(minLength: 6)
        }
        .contentShape(Rectangle())
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      favoriteButton(modelID: model.id)
      Image(systemName: "cloud")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .frame(width: 24, height: 24)
        .accessibilityLabel("Cloud model")
    }
    .frame(minHeight: model.presentationLabel == nil ? 20 : 34)
  }

  private func logoProvider(for model: CatalogModel) -> String {
    let provider = model.provider.lowercased()
    if provider.contains("google") { return "gemini" }
    if provider.contains("xai") { return "grok" }
    return model.provider
  }
}

private extension FluidAudioModelPackageState {
  var isBusy: Bool {
    switch self {
    case .checking, .downloading: true
    case .downloaded, .failed, .notDownloaded, .partial, .ready, .unknown: false
    }
  }

  var actionLabel: String {
    switch self {
    case .checking:
      "Checking model"
    case .downloaded:
      "Prepare model"
    case .downloading(let progress):
      "Downloading model, \(Self.percentage(progress)) percent"
    case .failed:
      "Retry model download"
    case .notDownloaded:
      "Download model"
    case .partial:
      "Finish downloading model"
    case .ready:
      "Delete model"
    case .unknown:
      "Check model download"
    }
  }

  func statusLabel(installedBytes: Int64) -> String {
    let size = installedBytes > 0 ? " · \(Self.formattedBytes(installedBytes))" : ""
    return switch self {
    case .checking:
      "Checking installation…"
    case .downloaded(let unverified):
      "Downloaded · \(unverified) to prepare\(size)"
    case .downloading(let progress):
      "Downloading · \(Self.percentage(progress))%"
    case .failed(let message):
      "Failed · \(message)"
    case .notDownloaded:
      "Not downloaded"
    case .partial(let downloaded, let verified, let total):
      "\(downloaded) of \(total) downloaded · \(verified) ready\(size)"
    case .ready:
      "Ready\(size)"
    case .unknown:
      "Installation status unavailable"
    }
  }

  var isFailure: Bool {
    if case .failed = self { return true }
    return false
  }

  private static func percentage(_ progress: Double) -> Int {
    Int((min(max(progress, 0), 1) * 100).rounded())
  }

  private static func formattedBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
  }
}
