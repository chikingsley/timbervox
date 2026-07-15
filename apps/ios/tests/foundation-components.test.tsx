import { render, screen } from "@testing-library/react-native";
import { SafeAreaProvider } from "react-native-safe-area-context";

import { AppBottomActionBar } from "@/components/app/app-bottom-action-bar";
import { RecordingControl } from "@/components/app/recording-control";
import { Text } from "@/components/ui/text";

describe("foundation components", () => {
  it("provides one shared surface for bottom actions", () => {
    render(
      <SafeAreaProvider
        initialMetrics={{
          frame: { height: 844, width: 390, x: 0, y: 0 },
          insets: { bottom: 34, left: 0, right: 0, top: 47 },
        }}
      >
        <AppBottomActionBar>
          <Text>Primary action</Text>
        </AppBottomActionBar>
      </SafeAreaProvider>,
    );

    expect(screen.getByText("Primary action")).toBeTruthy();
  });

  it.each([
    { label: "Start dictation", recording: false, text: "Dictate" },
    { label: "Stop dictation", recording: true, text: "Stop" },
  ])(
    "renders the $text recording control state",
    ({ label, recording, text }) => {
      render(<RecordingControl onPress={jest.fn()} recording={recording} />);

      expect(screen.getByLabelText(label)).toBeTruthy();
      expect(screen.getByText(text)).toBeTruthy();
    },
  );
});
