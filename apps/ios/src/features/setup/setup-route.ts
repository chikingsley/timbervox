function initialRouteForSetup(completed: boolean) {
  return completed ? ("/record" as const) : ("/welcome" as const);
}

export { initialRouteForSetup };
