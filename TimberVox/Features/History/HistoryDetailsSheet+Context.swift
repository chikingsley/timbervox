import Foundation

extension HistoryDetailsSheet {
  var contextRows: [HistoryMetadataValue] {
    guard let snapshot = record.contextSnapshot else { return [] }
    let context = snapshot.context
    var rows: [HistoryMetadataValue] = []
    if let windowTitle = context.application?.windowTitle,
      !windowTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      rows.append(HistoryMetadataValue(icon: "macwindow", label: "Window", value: windowTitle))
    }
    if let focusedElement = context.focusedElement {
      let description = [focusedElement.role, focusedElement.title]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
      if !description.isEmpty {
        rows.append(HistoryMetadataValue(icon: "scope", label: "Focused element", value: description))
      }
    }
    if !snapshot.selectedTextItems.isEmpty {
      rows.append(
        HistoryMetadataValue(
          icon: "selection.pin.in.out",
          label: "Selected text",
          value: Self.itemCount(snapshot.selectedTextItems.count)
        )
      )
    }
    if !snapshot.clipboardItems.isEmpty {
      rows.append(
        HistoryMetadataValue(
          icon: "clipboard",
          label: "Clipboard",
          value: Self.itemCount(snapshot.clipboardItems.count)
        )
      )
    }
    if let screenText = context.application?.screenText,
      !screenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      rows.append(HistoryMetadataValue(icon: "text.viewfinder", label: "Screen context", value: "Captured"))
    }
    if !snapshot.attachments.isEmpty {
      rows.append(
        HistoryMetadataValue(
          icon: "paperclip",
          label: "Attachments",
          value: Self.itemCount(snapshot.attachments.count)
        )
      )
    }
    if rows.isEmpty, context.application != nil {
      rows.append(HistoryMetadataValue(icon: "app", label: "Application context", value: "Captured"))
    }
    return rows
  }

  private static func itemCount(_ count: Int) -> String {
    count == 1 ? "1 item" : "\(count) items"
  }
}
