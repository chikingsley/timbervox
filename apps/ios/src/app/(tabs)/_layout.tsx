import { NativeTabs } from "expo-router/unstable-native-tabs";

export default function TabLayout() {
  return (
    <NativeTabs>
      <NativeTabs.Trigger name="record">
        <NativeTabs.Trigger.Label>Record</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon
          md={{ default: "mic", selected: "mic" }}
          sf={{ default: "waveform.circle", selected: "waveform.circle.fill" }}
        />
      </NativeTabs.Trigger>

      <NativeTabs.Trigger name="modes">
        <NativeTabs.Trigger.Label>Modes</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon
          md={{ default: "tune", selected: "tune" }}
          sf={{ default: "square.grid.2x2", selected: "square.grid.2x2.fill" }}
        />
      </NativeTabs.Trigger>

      <NativeTabs.Trigger name="history">
        <NativeTabs.Trigger.Label>History</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon
          md={{ default: "history", selected: "history" }}
          sf={{ default: "clock", selected: "clock.fill" }}
        />
      </NativeTabs.Trigger>

      <NativeTabs.Trigger name="settings">
        <NativeTabs.Trigger.Label>Settings</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon
          md={{ default: "settings", selected: "settings" }}
          sf={{ default: "gearshape", selected: "gearshape.fill" }}
        />
      </NativeTabs.Trigger>
    </NativeTabs>
  );
}
