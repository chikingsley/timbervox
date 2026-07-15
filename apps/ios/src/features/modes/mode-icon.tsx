import { SymbolView } from "expo-symbols";
import { View } from "react-native";

function ModeIcon({ iconKey, size = 22 }: { iconKey: string; size?: number }) {
  return (
    <View className="bg-primary/15 size-11 items-center justify-center rounded-2xl">
      <SymbolView name={iconKey as never} size={size} tintColor="#78a9ff" />
    </View>
  );
}

export { ModeIcon };
