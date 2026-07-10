import AVFoundation
import Inject
import SwiftUI

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
    Form {
      Section {
        VStack(spacing: 12) {
          Button {
            dictation.toggle()
          } label: {
            ZStack {
              Circle()
                .fill(dictation.isRecording ? Color.red : Color.accentColor)
                .frame(width: 64, height: 64)
              if dictation.state == .transcribing {
                ProgressView()
                  .controlSize(.small)
                  .tint(.white)
              } else {
                Image(systemName: dictation.isRecording ? "stop.fill" : "mic.fill")
                  .font(.system(size: 24, weight: .medium))
                  .foregroundStyle(.white)
              }
            }
          }
          .buttonStyle(.plain)
          .disabled(dictation.state == .transcribing)

          if case .recording(let started) = dictation.state {
            TimelineView(.periodic(from: started, by: 1)) { context in
              Text(Self.formatDuration(context.date.timeIntervalSince(started)))
                .font(.title3.weight(.medium))
                .monospacedDigit()
            }
            Text("⌥Space to stop · Esc to cancel")
              .font(.callout)
              .foregroundStyle(.secondary)
          } else {
            Text("Press ⌥Space in any app — your words paste wherever focus ends up")
              .font(.callout)
              .foregroundStyle(.secondary)
          }

          if let message = dictation.statusMessage {
            Text(message)
              .font(.callout)
              .foregroundStyle(.red)
              .multilineTextAlignment(.center)
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
      }

      if !axTrusted {
        Section {
          LabeledContent("Auto-paste is off") {
            Button("Grant Access") {
              AccessibilityPermission.requestPrompt()
            }
          }
        } footer: {
          Text("Grant Accessibility so your words land back in the app you're dictating into.")
        }
      }

      if !dictation.liveTranscript.isEmpty || dictation.state == .transcribing
        || dictation.lastTranscript != nil
      {
        Section("Last dictation") {
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
            VStack(alignment: .leading, spacing: 8) {
              Text(transcript)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
              HStack {
                if let note = dictation.lastDeliveryNote {
                  Text(note)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
                Spacer()
                Button("Copy", systemImage: "doc.on.doc") {
                  dictation.copyLastTranscript()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Copy to clipboard")
              }
            }
          }
        }
      }

      Section("Recent recordings") {
        if recordings.isEmpty {
          Text("Nothing yet — press ⌥Space and say something.")
            .foregroundStyle(.secondary)
        } else {
          ForEach(recordings) { item in
            Button {
              NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
              HStack {
                Label(
                  item.url.deletingPathExtension().lastPathComponent,
                  systemImage: "waveform"
                )
                Spacer()
                Text(Self.formatDuration(item.duration))
                  .monospacedDigit()
                  .foregroundStyle(.secondary)
                Text(item.date.formatted(date: .abbreviated, time: .shortened))
                  .foregroundStyle(.secondary)
              }
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
          }
        }
      }
    }
    .formStyle(.grouped)
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
