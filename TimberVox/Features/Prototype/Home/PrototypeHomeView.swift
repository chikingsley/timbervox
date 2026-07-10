import Inject
import SwiftUI

struct PrototypeHomeView: View {
  let navigate: (PrototypeDestination) -> Void
  @ObserveInjection var injection

  var body: some View {
    Form {
      dictationSection
      recentSection
      quickStartSection
      activitySection
    }
    .formStyle(.grouped)
    .navigationTitle("Home")
    .enableInjection()
  }

  private var dictationSection: some View {
    Section {
      LabeledContent("Status") {
        Label("Ready", systemImage: "checkmark.circle.fill")
          .foregroundStyle(.green)
      }
      LabeledContent("Active mode") {
        Button("Voice to Text") { navigate(.modes) }
      }
      LabeledContent("Shortcut") {
        Text("⌥ Space")
          .monospaced()
      }
    } header: {
      Text("Dictation")
    } footer: {
      Text("Dictation starts from the global shortcut and returns text to the app where you are working.")
    }
  }

  private var recentSection: some View {
    Section("Most recent") {
      Text("Could we move the design review to Thursday afternoon? I will send the revised prototype beforehand.")
        .textSelection(.enabled)

      HStack {
        Text("Mail · Email mode · 7 minutes ago")
          .foregroundStyle(.secondary)
        Spacer()
        Button("Copy", systemImage: "doc.on.doc") {}
        Button("Open in History") { navigate(.history) }
      }
    }
  }

  private var quickStartSection: some View {
    Section("Quick starts") {
      LabeledContent {
        Button("Start") {}
      } label: {
        Label("Voice Memo", systemImage: "waveform")
        Text("Record a standalone note")
      }

      LabeledContent {
        Button("Choose Files…") { navigate(.transcriptions) }
      } label: {
        Label("Import Files", systemImage: "square.and.arrow.down")
        Text("Create durable transcripts from audio or video")
      }

      LabeledContent {
        Button("New Meeting") { navigate(.meetings) }
      } label: {
        Label("Meeting", systemImage: "person.2.wave.2")
        Text("Configure microphone and system audio before recording")
      }
    }
  }

  private var activitySection: some View {
    Section("Last 30 days") {
      LabeledContent("Words dictated", value: "18,420")
      LabeledContent("Recorded time", value: "2 hr 14 min")
      LabeledContent("Average dictation speed", value: "138 words/min")
      LabeledContent {
        Button("Calibrate…") {}
      } label: {
        Text("Estimated time saved")
        Text("3 hr 42 min, based on a 45 words/min typing speed")
      }
    }
  }
}

#Preview("Home") {
  PrototypeHomeView { _ in }
    .frame(width: 900, height: 720)
}
