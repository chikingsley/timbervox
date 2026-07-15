import { Button } from "@/components/ui/button";
import { Text } from "@/components/ui/text";
import { SymbolView } from "expo-symbols";

type RecordingControlProps = {
  onPress: () => void;
  recording: boolean;
};

function RecordingControl({ onPress, recording }: RecordingControlProps) {
  const label = recording ? "Stop" : "Dictate";

  return (
    <Button
      accessibilityLabel={recording ? "Stop dictation" : "Start dictation"}
      className="h-14 w-full rounded-2xl"
      onPress={onPress}
      variant={recording ? "destructive" : "default"}
    >
      <SymbolView
        name={recording ? "stop.fill" : "mic.fill"}
        size={24}
        tintColor="#ffffff"
      />
      <Text className="text-base font-bold">{label}</Text>
    </Button>
  );
}

export { RecordingControl };
