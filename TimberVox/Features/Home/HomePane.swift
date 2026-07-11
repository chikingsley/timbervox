import AVFoundation
import Inject
import SwiftUI
import Swiftcn

struct RecordingItem: Identifiable, Sendable {
  let url: URL
  let date: Date
  let duration: TimeInterval

  var id: URL { url }
}

struct HomePane: View {
  let dictation: DictationController
  @State private var recordings: [RecordingItem] = []
  @State private var axTrusted = true
  @ObserveInjection var injection

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        dictationCard

        if !axTrusted {
          SCAlert(icon: "exclamationmark.triangle") {
            SCAlertTitle("Auto-paste is off")
            SCAlertDescription(
              "Grant Accessibility so your words land back in the app you're dictating into."
            )
            Button("Grant Access") {
              AccessibilityPermission.requestPrompt()
            }
            .buttonStyle(.sc(.outline, size: .sm))
          }
        }

        if !dictation.liveTranscript.isEmpty || dictation.state == .transcribing
          || dictation.lastTranscript != nil
        {
          lastDictationCard
        }

        recentRecordingsCard
      }
      .frame(maxWidth: 860)
      .padding(24)
      .frame(maxWidth: .infinity)
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .theme(.default)
    .navigationTitle("Home")
    .task(id: dictation.lastRecordingURL) {
      recordings = Self.loadRecordings()
    }
    .task {
      axTrusted = AccessibilityPermission.isTrusted
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1))
        axTrusted = AccessibilityPermission.isTrusted
      }
    }
    .enableInjection()
  }

  private var dictationCard: some View {
    SCCard {
      HStack(alignment: .center, spacing: 20) {
        VStack(alignment: .leading, spacing: 6) {
          SCCardTitle(dictationTitle)
          SCCardDescription(dictationDescription)

          if case .recording(let started) = dictation.state {
            TimelineView(.periodic(from: started, by: 1)) { context in
              Text(Self.formatDuration(context.date.timeIntervalSince(started)))
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            }
          }
        }

        Spacer(minLength: 24)

        Button {
          dictation.toggle()
        } label: {
          Label(dictationButtonTitle, systemImage: dictationButtonIcon)
        }
        .buttonStyle(.sc(dictationButtonVariant, size: .lg))
        .disabled(dictation.state == .transcribing)
      }

      if let message = dictation.statusMessage {
        SCAlert(
          icon: "exclamationmark.circle",
          title: "Dictation issue",
          description: message,
          variant: .destructive
        )
      }
    }
  }

  private var lastDictationCard: some View {
    SCCard {
      SCCardHeader {
        SCCardTitle("Last dictation")
        SCCardDescription("The latest text TimberVox heard and delivered.")
      }
      SCCardContent {
        if dictation.state == .transcribing {
          HStack(spacing: 8) {
            ProgressView()
              .controlSize(.small)
            Text("Transcribing…")
              .foregroundStyle(.secondary)
          }
        } else if !dictation.liveTranscript.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Text("Live")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.tint)
            Text(dictation.liveTranscript)
              .textSelection(.enabled)
          }
        } else if let transcript = dictation.lastTranscript {
          Text(transcript)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      SCCardFooter {
        if let note = dictation.lastDeliveryNote {
          Text(note)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button("Copy", systemImage: "doc.on.doc") {
          dictation.copyLastTranscript()
        }
        .buttonStyle(.sc(.outline, size: .sm))
      }
    }
  }

  private var recentRecordingsCard: some View {
    SCCard {
      SCCardHeader {
        SCCardTitle("Recent recordings")
        SCCardDescription("Audio retained from your latest dictations.")
      }
      SCCardContent {
        if recordings.isEmpty {
          Text("Nothing yet — press ⌥Space and say something.")
            .foregroundStyle(.secondary)
        } else {
          VStack(spacing: 0) {
            ForEach(Array(recordings.enumerated()), id: \.element.id) { index, item in
              if index > 0 {
                Divider()
              }
              Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
              } label: {
                SCItem(
                  item.url.deletingPathExtension().lastPathComponent,
                  description: item.date.formatted(date: .abbreviated, time: .shortened)
                ) {
                  Image(systemName: "waveform")
                } trailing: {
                  Text(Self.formatDuration(item.duration))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                }
              }
              .buttonStyle(.plain)
              .help("Reveal in Finder")
            }
          }
        }
      }
    }
  }

  private var dictationTitle: String {
    switch dictation.state {
    case .idle: "Ready to dictate"
    case .recording: "Listening…"
    case .transcribing: "Transcribing…"
    }
  }

  private var dictationDescription: String {
    switch dictation.state {
    case .idle: "Press ⌥Space in any app, or start here. Your words return to where you were working."
    case .recording: "Press ⌥Space to stop or Escape to cancel."
    case .transcribing: "TimberVox is preparing and delivering your text."
    }
  }

  private var dictationButtonTitle: String {
    switch dictation.state {
    case .idle: "Start Dictation"
    case .recording: "Stop Dictation"
    case .transcribing: "Transcribing"
    }
  }

  private var dictationButtonIcon: String {
    dictation.isRecording ? "stop.fill" : "mic.fill"
  }

  private var dictationButtonVariant: SCButtonVariant {
    dictation.isRecording ? .destructive : .default
  }

  static func formatDuration(_ seconds: TimeInterval) -> String {
    Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
  }

  static func loadRecordings() -> [RecordingItem] {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("TimberVox/Recordings")
    guard
      let urls = try? FileManager.default.contentsOfDirectory(
        at: base,
        includingPropertiesForKeys: [.contentModificationDateKey],
        options: .skipsHiddenFiles
      )
    else {
      return []
    }

    return
      urls
      .filter { $0.pathExtension == "wav" }
      .compactMap { url -> RecordingItem? in
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let date =
          (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
          ?? .distantPast
        let duration = Double(file.length) / file.fileFormat.sampleRate
        return RecordingItem(url: url, date: date, duration: duration)
      }
      .sorted { $0.date > $1.date }
      .prefix(10)
      .map { $0 }
  }
}
