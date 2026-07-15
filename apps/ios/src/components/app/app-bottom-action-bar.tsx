import { cn } from "@/lib/utils";
import type { PropsWithChildren } from "react";
import { View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

type AppBottomActionBarProps = PropsWithChildren<{
  className?: string;
}>;

function AppBottomActionBar({
  children,
  className,
}: AppBottomActionBarProps) {
  const insets = useSafeAreaInsets();

  return (
    <View
      className={cn(
        "border-border bg-background border-t px-[18px] pt-3",
        className,
      )}
      style={{ paddingBottom: insets.bottom + 20 }}
    >
      {children}
    </View>
  );
}

export { AppBottomActionBar };
export type { AppBottomActionBarProps };
