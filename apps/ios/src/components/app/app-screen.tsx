import { cn } from "@/lib/utils";
import type { PropsWithChildren } from "react";
import { ScrollView, View, type ScrollViewProps } from "react-native";
import { SafeAreaView, type Edge } from "react-native-safe-area-context";

type AppScreenProps = PropsWithChildren<{
  className?: string;
  contentClassName?: string;
  edges?: Edge[];
  keyboardShouldPersistTaps?: ScrollViewProps["keyboardShouldPersistTaps"];
  scroll?: boolean;
}>;

function AppScreen({
  children,
  className,
  contentClassName,
  edges = ["left", "right"],
  keyboardShouldPersistTaps,
  scroll = false,
}: AppScreenProps) {
  if (scroll) {
    return (
      <ScrollView
        className={cn("bg-background flex-1", className)}
        contentContainerClassName={cn(
          "gap-3 px-[18px] pt-[18px] pb-[120px]",
          contentClassName,
        )}
        keyboardShouldPersistTaps={keyboardShouldPersistTaps}
      >
        {children}
      </ScrollView>
    );
  }

  return (
    <SafeAreaView
      className={cn("bg-background flex-1 pb-24", className)}
      edges={edges}
    >
      <View className={cn("flex-1", contentClassName)}>{children}</View>
    </SafeAreaView>
  );
}

export { AppScreen };
export type { AppScreenProps };
