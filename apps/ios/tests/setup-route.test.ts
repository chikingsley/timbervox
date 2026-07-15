import { initialRouteForSetup } from "@/features/setup/setup-route";

describe("initialRouteForSetup", () => {
  it("routes unfinished setup to onboarding", () => {
    expect(initialRouteForSetup(false)).toBe("/welcome");
  });

  it("routes finished setup to Record", () => {
    expect(initialRouteForSetup(true)).toBe("/record");
  });
});
