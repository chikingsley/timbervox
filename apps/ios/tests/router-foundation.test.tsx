import { router } from "expo-router";
import { act, renderRouter, waitFor } from "expo-router/testing-library";

const FOUNDATION_ROUTES = [
  "(onboarding)/welcome",
  "(tabs)/record/index",
  "(tabs)/modes/index",
  "(tabs)/history/index",
  "(tabs)/settings/index",
];

describe("foundation routes", () => {
  it("keeps onboarding separate and opens every tab root", async () => {
    const result = renderRouter(FOUNDATION_ROUTES, { initialUrl: "/welcome" });

    await waitFor(() =>
      expect(result.getSegments()).toEqual(["(onboarding)", "welcome"]),
    );

    for (const pathname of [
      "/record",
      "/modes",
      "/history",
      "/settings",
      "/record",
    ] as const) {
      await act(async () => router.navigate(pathname));
      await waitFor(() => expect(result.getPathname()).toBe(pathname));
    }

    await act(async () => router.navigate("/record"));
    await waitFor(() => expect(result.getPathname()).toBe("/record"));
  });
});
