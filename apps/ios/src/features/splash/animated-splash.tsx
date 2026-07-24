import * as SplashScreen from "expo-splash-screen";
import { useEffect, useState } from "react";
import { Image, StyleSheet } from "react-native";
import Animated, {
  cancelAnimation,
  Easing,
  runOnJS,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withSequence,
  withTiming,
} from "react-native-reanimated";

// The native splash is a static frame of this exact composition. This overlay
// takes over on the first JS frame, pulses the mark while the app finishes
// booting, then fades away — so launch reads as one continuous animation
// instead of a frozen icon card.
SplashScreen.preventAutoHideAsync().catch(() => {});

const MARK = require("../../../assets/images/splash-mark.png") as number;
const BACKGROUND = "#21160b";
const MARK_SIZE = 240;
const MINIMUM_VISIBLE_MS = 1400;

function AnimatedSplash() {
  const [dismissed, setDismissed] = useState(false);
  const scale = useSharedValue(1);
  const opacity = useSharedValue(1);

  useEffect(() => {
    scale.value = withRepeat(
      withSequence(
        withTiming(1.06, { duration: 700, easing: Easing.inOut(Easing.quad) }),
        withTiming(1, { duration: 700, easing: Easing.inOut(Easing.quad) }),
      ),
      -1,
    );
    const timer = setTimeout(() => {
      cancelAnimation(scale);
      scale.value = withTiming(1.4, {
        duration: 420,
        easing: Easing.in(Easing.quad),
      });
      opacity.value = withTiming(
        0,
        { duration: 420, easing: Easing.out(Easing.quad) },
        (finished) => {
          if (finished) runOnJS(setDismissed)(true);
        },
      );
    }, MINIMUM_VISIBLE_MS);
    return () => clearTimeout(timer);
  }, [opacity, scale]);

  const containerStyle = useAnimatedStyle(() => ({ opacity: opacity.value }));
  const markStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  if (dismissed) return null;

  return (
    <Animated.View
      pointerEvents="none"
      style={[styles.container, containerStyle]}
      onLayout={() => {
        SplashScreen.hideAsync().catch(() => {});
      }}
    >
      <Animated.View style={markStyle}>
        <Image
          fadeDuration={0}
          source={MARK}
          style={{ height: MARK_SIZE, width: MARK_SIZE }}
        />
      </Animated.View>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: "center",
    backgroundColor: BACKGROUND,
    bottom: 0,
    justifyContent: "center",
    left: 0,
    position: "absolute",
    right: 0,
    top: 0,
    zIndex: 1000,
  },
});

export { AnimatedSplash };
