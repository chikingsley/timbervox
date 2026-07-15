import { fireEvent, render, screen } from "@testing-library/react-native";

import {
  existingModeEditorState,
  MODE_ICON_COLUMNS,
  MODE_ICONS,
  optionalModeFields,
} from "@/features/modes/mode-editor-contract";
import { ModeEditorHeader } from "@/features/modes/mode-editor-screen";

describe("mode editor interaction contract", () => {
  it("keeps the header in display mode and exposes deliberate edit actions", () => {
    const onChangeIcon = jest.fn();
    const onRename = jest.fn();

    render(
      <ModeEditorHeader
        iconKey="message.fill"
        name="Message"
        onChangeIcon={onChangeIcon}
        onRename={onRename}
      />,
    );

    expect(screen.queryByDisplayValue("Message")).toBeNull();
    fireEvent.press(screen.getByLabelText("Change mode icon"));
    fireEvent.press(screen.getByLabelText("Rename Message mode"));
    expect(onChangeIcon).toHaveBeenCalledTimes(1);
    expect(onRename).toHaveBeenCalledTimes(1);
  });

  it("uses a dense complete icon grid contract", () => {
    expect(MODE_ICON_COLUMNS).toBe(8);
    expect(MODE_ICONS).toHaveLength(30);
    expect(new Set(MODE_ICONS).size).toBe(MODE_ICONS.length);
  });

  it("does not leave stale or missing mode routes loading forever", () => {
    expect(
      existingModeEditorState({
        modeId: "voice",
        modesLoading: true,
        storedModeExists: false,
      }),
    ).toBe("loading");
    expect(
      existingModeEditorState({
        modeId: "deleted-mode",
        modesLoading: false,
        storedModeExists: false,
      }),
    ).toBe("missing");
    expect(
      existingModeEditorState({
        draftId: "voice",
        modeId: "voice",
        modesLoading: false,
        storedModeExists: true,
      }),
    ).toBe("ready");
  });

  it("shows language models for every processing preset and instructions only for Custom", () => {
    expect(
      optionalModeFields({
        presetKind: "message",
        supportsDiarization: false,
      }),
    ).toEqual(["languageModel"]);
    expect(
      optionalModeFields({
        presetKind: "custom",
        supportsDiarization: true,
      }),
    ).toEqual(["identifySpeakers", "languageModel", "instructions"]);
    expect(
      optionalModeFields({
        presetKind: "voice",
        supportsDiarization: false,
      }),
    ).toEqual([]);
  });
});
