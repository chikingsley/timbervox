import SwiftUI

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
      estimatedRowHeight: 50,
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
      row: { option, selected, select in
        if let model = model(for: option) {
          modelRow(model, isSelected: selected, select: select)
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
    isSelected: Bool,
    select: SCComboboxSelectionAction
  ) -> some View {
    HStack(spacing: 9) {
      SCComboboxRowAction(
        accessibilityLabel: [model.displayName, model.presentationLabel]
          .compactMap { $0 }
          .joined(separator: ", "),
        isSelected: isSelected
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
    .background(
      isSelected ? Color.primary.opacity(0.07) : .clear,
      in: RoundedRectangle(cornerRadius: 6, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .strokeBorder(isSelected ? Color.primary.opacity(0.22) : .clear)
    }
  }

  private func logoProvider(for model: CatalogModel) -> String {
    let provider = model.provider.lowercased()
    if provider.contains("google") { return "gemini" }
    if provider.contains("xai") { return "grok" }
    return model.provider
  }
}
