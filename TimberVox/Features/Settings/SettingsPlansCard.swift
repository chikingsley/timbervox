import SwiftUI

/// The plans card — the ui-prototype's Pro/license card: plan rows with an
/// Active badge or a Subscribe action, plus purchase restore.
struct SettingsPlansCard: View {
  let billing: SubscriptionController

  @Environment(\.theme) private var theme

  var body: some View {
    AppSettingsCard(
      "TimberVox Pro",
      description:
        "Cloud Access enables hosted transcription and text processing. Local Pro will unlock offline features when they ship."
    ) {
      AppSettingsRow("Cloud Access", detail: billing.cloudPrice) {
        if billing.cloudAccessIsActive {
          activeBadge
        } else {
          Button("Subscribe") {
            Task { await billing.purchaseCloudAccess() }
          }
          .buttonStyle(.sc(.secondary, size: .sm))
          .disabled(!billing.isConfigured || billing.isLoading)
        }
      }

      SCSeparator()

      AppSettingsRow("Local Pro", detail: billing.localProPrice) {
        if billing.localProIsActive {
          activeBadge
        } else {
          Text("Coming soon")
            .font(.system(size: 12))
            .foregroundStyle(theme.mutedForeground)
        }
      }

      SCSeparator()

      HStack {
        Button("Restore Purchases") {
          Task { await billing.restorePurchases() }
        }
        .buttonStyle(.sc(.outline, size: .sm))
        .disabled(!billing.isConfigured || billing.isLoading)

        if billing.isLoading {
          SCSpinner(size: 12, lineWidth: 1.5)
        }
      }

      if let error = billing.lastError {
        Text(error)
          .font(.system(size: 11))
          .foregroundStyle(theme.destructive)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var activeBadge: some View {
    Label("Active", systemImage: "checkmark.circle.fill")
      .font(.system(size: 12, weight: .medium))
      .foregroundStyle(.green)
  }
}
