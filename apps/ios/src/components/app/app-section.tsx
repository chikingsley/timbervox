import { Card, CardContent } from "@/components/ui/card";
import { Text } from "@/components/ui/text";
import { cn } from "@/lib/utils";
import type { PropsWithChildren } from "react";
import { View } from "react-native";

type AppSectionProps = PropsWithChildren<{
  className?: string;
  contentClassName?: string;
  title?: string;
}>;

function AppSection({
  children,
  className,
  contentClassName,
  title,
}: AppSectionProps) {
  return (
    <View className={cn(title && "gap-2.5", className)}>
      {title ? (
        <Text className="text-muted-foreground ml-1.5 text-xs font-extrabold tracking-widest uppercase">
          {title}
        </Text>
      ) : null}
      <Card className="gap-0 rounded-[20px] border-0 py-0 shadow-none">
        <CardContent className={cn("px-[17px]", contentClassName)}>
          {children}
        </CardContent>
      </Card>
    </View>
  );
}

export { AppSection };
