import { SymbolView } from "expo-symbols";
import { createNanoIconSet } from "react-native-nano-icons";
import { type ColorValue, View } from "react-native";

import providerGlyphMap from "@/assets/icons/nanoicons/TimberVoxProviders.glyphmap.json";

const ProviderMark = createNanoIconSet(providerGlyphMap);

const PROVIDER_MARKS = {
  anthropic: { name: "anthropic" },
  cerebras: { color: "#F15A29", name: "cerebras" },
  deepgram: { color: "#13EF93", name: "deepgram" },
  deepseek: { color: "#4D6BFE", name: "deepseek" },
  elevenlabs: { name: "elevenlabs" },
  google: { color: "#9BA5FF", name: "gemini" },
  groq: { color: "#F55036", name: "groq" },
  mistral: { name: "mistral" },
  nvidia: { name: "nvidia" },
  openai: { name: "openai" },
  zai: { name: "zai" },
} as const satisfies Readonly<
  Record<string, { color?: ColorValue; name: keyof typeof providerGlyphMap.i }>
>;

function ProviderIcon({ provider }: { provider: string }) {
  const mark = PROVIDER_MARKS[provider as keyof typeof PROVIDER_MARKS];

  return (
    <View className="size-9 items-center justify-center">
      {mark ? (
        <ProviderMark
          accessibilityLabel={`${provider} logo`}
          allowFontScaling={false}
          color={"color" in mark ? mark.color : undefined}
          name={mark.name}
          size={27}
        />
      ) : (
        <SymbolView name="waveform" size={22} tintColor="#8b929f" />
      )}
    </View>
  );
}

export { ProviderIcon };
