import { Redirect } from "expo-router";

import { initialRouteForSetup } from "@/features/setup/setup-route";
import { useSetupState } from "@/features/setup/setup-state";

export default function IndexRoute() {
  const setup = useSetupState();
  return <Redirect href={initialRouteForSetup(setup.completed)} />;
}
