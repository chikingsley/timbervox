import Inject
import SwiftUI

struct PrototypeMeetingsView: View {
  @Binding var destination: PrototypeDestination?
  enum Stage {
    case library
    case setup
    case live
    case finalizing
    case result
  }

  @State private var meetings = PrototypeMeeting.samples
  @State private var selectedID = PrototypeMeeting.samples.first?.id
  @State private var stage = Stage.library
  @State private var meetingTitle = "Design review"
  @State private var includesSystemAudio = true
  @State private var elapsedSeconds = 754.0
  @ObserveInjection var injection

  private var selected: PrototypeMeeting? { meetings.first { $0.id == selectedID } }

  var body: some View {
    PrototypeCollectionLayout(destination: $destination) {
      meetingList
    } detail: {
      Group { detail }
        .toolbar { detailToolbar }
    }
    .navigationTitle(detailTitle)
    .enableInjection()
  }

  private var meetingList: some View {
    List(selection: $selectedID) {
      Section("Recent Meetings") {
        ForEach(meetings) { meeting in
          VStack(alignment: .leading, spacing: 4) {
            Text(meeting.title)
            HStack {
              Text(meeting.date.formatted(date: .abbreviated, time: .shortened))
              Text("·")
              Text(PrototypeFormat.duration(meeting.duration))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
          }
          .padding(.vertical, 3)
          .tag(meeting.id)
        }
      }
    }
    .searchable(text: .constant(""), prompt: "Search meetings")
    .onChange(of: selectedID) { _, _ in stage = .result }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("New Meeting", systemImage: "plus") { stage = .setup }
      }
    }
  }

  @ToolbarContentBuilder private var detailToolbar: some ToolbarContent {
    if stage == .live {
      ToolbarItem(placement: .primaryAction) {
        Button("Stop Meeting", systemImage: "stop.fill", role: .destructive) {
          stage = .finalizing
        }
      }
    }
  }

  private var detailTitle: String {
    switch stage {
    case .library, .result: selected?.title ?? "Meeting"
    case .setup: "New Meeting"
    case .live: meetingTitle
    case .finalizing: "Finalizing"
    }
  }

  @ViewBuilder private var detail: some View {
    switch stage {
    case .library, .result:
      if let selected {
        PrototypeMeetingResult(meeting: selected)
      } else {
        ContentUnavailableView(
          "No Meetings", systemImage: "person.2.wave.2",
          description: Text("Create a meeting to record microphone and system audio."))
      }
    case .setup:
      setupView
    case .live:
      liveView
    case .finalizing:
      finalizingView
    }
  }

  private var setupView: some View {
    Form {
      Section("New Meeting") {
        TextField("Title", text: $meetingTitle)
        Picker("Microphone", selection: .constant("MacBook Pro Microphone")) {
          Text("MacBook Pro Microphone").tag("MacBook Pro Microphone")
          Text("External Microphone").tag("External Microphone")
        }
        Toggle("Record system audio", isOn: $includesSystemAudio)
      }

      if includesSystemAudio {
        Section("System Audio Access") {
          LabeledContent {
            Label("Granted", systemImage: "checkmark.circle.fill")
              .foregroundStyle(.green)
          } label: {
            Text("Permission")
            Text("Requested here because this meeting will capture system audio")
          }
        }
      }

      Section("Transcription") {
        Picker("Language", selection: .constant("Automatic")) {
          Text("Automatic").tag("Automatic")
          Text("English").tag("English")
        }
        Picker("Final model", selection: .constant("Nova 3")) {
          Text("Nova 3").tag("Nova 3")
          Text("Scribe v2").tag("Scribe v2")
        }
      }

      HStack {
        Button("Cancel") { stage = .library }
        Spacer()
        Button("Start Meeting") { stage = .live }
          .buttonStyle(.borderedProminent)
      }
    }
    .formStyle(.grouped)
  }

  private var liveView: some View {
    VStack(spacing: 0) {
      Form {
        Section("Recording") {
          LabeledContent("Meeting", value: meetingTitle)
          LabeledContent("Elapsed") {
            Text(PrototypeFormat.duration(elapsedSeconds))
              .monospacedDigit()
          }
          LabeledContent("Microphone") {
            Label("Good", systemImage: "waveform")
              .foregroundStyle(.green)
          }
          LabeledContent("System audio") {
            Label(
              includesSystemAudio ? "Recording" : "Off",
              systemImage: includesSystemAudio ? "speaker.wave.2.fill" : "speaker.slash")
          }
        }

        Section("Live Transcript") {
          Text("Simon  We should keep the prototype separate from the production controller so we can iterate quickly.")
          Text("Maya  Agreed. The meeting result can reuse the same transcript editor as imported files.")
          Text("Simon  Let’s verify the navigation at the default window size before promoting anything.")
        }
      }
      .formStyle(.grouped)

      Divider()
      HStack {
        Label("Local master recording is being saved", systemImage: "externaldrive.fill")
          .foregroundStyle(.secondary)
        Spacer()
        Button("Stop Meeting", role: .destructive) { stage = .finalizing }
          .buttonStyle(.borderedProminent)
      }
      .padding()
    }
  }

  private var finalizingView: some View {
    ContentUnavailableView {
      Label("Finalizing Meeting", systemImage: "gearshape.2")
    } description: {
      Text("The local master is safe. TimberVox is producing the final transcript and speaker labels.")
    } actions: {
      ProgressView(value: 0.65)
        .frame(width: 260)
      Button("Show Result") {
        let meeting = PrototypeMeeting(
          id: UUID(), title: meetingTitle, date: .now, duration: elapsedSeconds,
          participants: ["Simon", "Maya"],
          summary:
            "The team reviewed the connected TimberVox prototype and agreed to keep runtime integration separate from visual iteration.",
          actionItems: ["Review every destination", "Verify default and compact window sizes"])
        meetings.insert(meeting, at: 0)
        selectedID = meeting.id
        stage = .result
      }
    }
  }
}

private struct PrototypeMeetingResult: View {
  let meeting: PrototypeMeeting

  var body: some View {
    Form {
      Section("Summary") {
        Text(meeting.summary)
          .textSelection(.enabled)
      }

      Section("Participants") {
        ForEach(meeting.participants, id: \.self) { participant in
          Label(participant, systemImage: "person.crop.circle")
        }
      }

      Section("Action Items") {
        ForEach(meeting.actionItems, id: \.self) { item in
          Toggle(item, isOn: .constant(false))
        }
      }

      Section("Transcript") {
        LabeledContent {
          Button("Open Transcript") {}
        } label: {
          Text("Final transcript")
          Text("Editable with speaker labels and synchronized playback")
        }
        LabeledContent("Recording", value: PrototypeFormat.duration(meeting.duration))
      }

      Section("Notes") {
        TextEditor(text: .constant("Add notes about decisions, follow-ups, or context…"))
          .frame(minHeight: 100)
      }
    }
    .formStyle(.grouped)
  }
}

#Preview("Meetings") {
  PrototypeMeetingsView(destination: .constant(.meetings))
    .frame(width: 980, height: 720)
}
