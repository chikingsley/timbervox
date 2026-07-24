#!/usr/bin/env python3
"""Author and sign the TimberVox wrapper shortcut.

The wrapper mirrors the Superwhisper pattern around our AudioRecordingIntent:
toggle -> if finished text exists -> copy -> combine clipboard with spaces ->
notify with the combined text -> vibrate. The output is a signed .shortcut file
bundled into the app so a user can add it with one tap; unsigned shortcut files
cannot be imported on iOS at all.

Run on macOS (needs the `shortcuts` CLI):
    python3 scripts/generate-wrapper-shortcut.py
"""

import plistlib
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

BUNDLE = "studio.peacockery.timbervox"
TEAM = "XM69J99HWP"
NAME = "Toggle TimberVox Dictation"
OUTPUT = Path(__file__).resolve().parent.parent / "assets" / "shortcuts" / f"{NAME}.shortcut"


def output_ref(name: str, out_uuid: str) -> dict:
    return {
        "Value": {"OutputName": name, "OutputUUID": out_uuid, "Type": "ActionOutput"},
        "WFSerializationType": "WFTextTokenAttachment",
    }


def build_workflow() -> dict:
    intent_uuid = str(uuid.uuid4()).upper()
    group_uuid = str(uuid.uuid4()).upper()
    combine_uuid = str(uuid.uuid4()).upper()

    actions = [
        {
            "WFWorkflowActionIdentifier": f"{BUNDLE}.AudioRecordingIntent",
            "WFWorkflowActionParameters": {
                "AppIntentDescriptor": {
                    "AppIntentIdentifier": "AudioRecordingIntent",
                    "BundleIdentifier": BUNDLE,
                    "Name": "TimberVox",
                    "TeamIdentifier": TEAM,
                },
                "ShowWhenRun": False,
                "UUID": intent_uuid,
            },
        },
        {
            "WFWorkflowActionIdentifier": "is.workflow.actions.conditional",
            "WFWorkflowActionParameters": {
                "GroupingIdentifier": group_uuid,
                # WFCondition codes: 0-3 numeric comparisons, 4 "is", 5
                # "is not", 100 "has any value" (rendered by the editor as
                # "is anything" — Superwhisper's wrapper uses the same). A 4/5
                # comparison without an operand is incomplete and makes
                # Shortcuts refuse to run with "Select a value", which is the
                # failure the hand-built shortcut had.
                "WFCondition": 100,  # has any value
                "WFControlFlowMode": 0,
                "WFInput": {
                    "Type": "Variable",
                    "Variable": output_ref(NAME, intent_uuid),
                },
            },
        },
        {
            "WFWorkflowActionIdentifier": "is.workflow.actions.setclipboard",
            "WFWorkflowActionParameters": {
                "UUID": str(uuid.uuid4()).upper(),
                "WFInput": output_ref(NAME, intent_uuid),
            },
        },
        {
            "WFWorkflowActionIdentifier": "is.workflow.actions.text.combine",
            "WFWorkflowActionParameters": {
                "UUID": combine_uuid,
                "text": {
                    "Value": {"Type": "Clipboard"},
                    "WFSerializationType": "WFTextTokenAttachment",
                },
                "WFTextSeparator": "Spaces",
            },
        },
        {
            "WFWorkflowActionIdentifier": "is.workflow.actions.notification",
            "WFWorkflowActionParameters": {
                "UUID": str(uuid.uuid4()).upper(),
                "WFNotificationActionBody": {
                    "Value": {
                        "attachmentsByRange": {
                            "{0, 1}": {
                                "OutputName": "Combined Text",
                                "OutputUUID": combine_uuid,
                                "Type": "ActionOutput",
                            }
                        },
                        "string": "￼",
                    },
                    "WFSerializationType": "WFTextTokenString",
                },
            },
        },
        {
            "WFWorkflowActionIdentifier": "is.workflow.actions.vibrate",
            "WFWorkflowActionParameters": {},
        },
        {
            "WFWorkflowActionIdentifier": "is.workflow.actions.conditional",
            "WFWorkflowActionParameters": {
                "GroupingIdentifier": group_uuid,
                "UUID": str(uuid.uuid4()).upper(),
                "WFControlFlowMode": 2,
            },
        },
    ]

    return {
        "WFWorkflowActions": actions,
        "WFWorkflowClientVersion": "3606.0.3",
        "WFWorkflowHasOutputFallback": False,
        "WFWorkflowHasShortcutInputVariables": False,
        "WFWorkflowIcon": {
            "WFWorkflowIconGlyphNumber": 61440,
            "WFWorkflowIconStartColor": -615917313,
        },
        "WFWorkflowImportQuestions": [],
        "WFWorkflowInputContentItemClasses": [
            "WFAppContentItem", "WFAppStoreAppContentItem", "WFArticleContentItem",
            "WFContactContentItem", "WFDateContentItem", "WFEmailAddressContentItem",
            "WFFolderContentItem", "WFGenericFileContentItem", "WFImageContentItem",
            "WFiTunesProductContentItem", "WFLocationContentItem", "WFDCMapsLinkContentItem",
            "WFAVAssetContentItem", "WFPDFContentItem", "WFPhoneNumberContentItem",
            "WFRichTextContentItem", "WFSafariWebPageContentItem", "WFStringContentItem",
            "WFURLContentItem",
        ],
        "WFWorkflowMinimumClientVersion": 900,
        "WFWorkflowMinimumClientVersionString": "900",
        "WFWorkflowOutputContentItemClasses": [],
        "WFWorkflowTypes": [],
    }


def main() -> int:
    with tempfile.NamedTemporaryFile(suffix=".shortcut", delete=False) as handle:
        plistlib.dump(build_workflow(), handle, fmt=plistlib.FMT_BINARY)
        unsigned = handle.name
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["shortcuts", "sign", "--mode", "anyone", "-i", unsigned, "-o", str(OUTPUT)],
        check=True,
    )
    magic = OUTPUT.read_bytes()[:4]
    if magic != b"AEA1":
        print(f"signing produced unexpected magic {magic!r}", file=sys.stderr)
        return 1
    print(f"signed wrapper written to {OUTPUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
