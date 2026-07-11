import type { TranscriptSpeakerTurn, TranscriptWord } from "./types";

export const speakerTurnsFromWords = (
  words: readonly TranscriptWord[]
): TranscriptSpeakerTurn[] => {
  const turns: TranscriptSpeakerTurn[] = [];
  for (const word of words) {
    if (word.speaker === undefined) {
      continue;
    }
    const current = turns.at(-1);
    if (current?.speaker === word.speaker) {
      current.endSeconds = word.endSeconds;
      current.text = `${current.text} ${word.text}`.trim();
      continue;
    }
    turns.push({
      endSeconds: word.endSeconds,
      speaker: word.speaker,
      startSeconds: word.startSeconds,
      text: word.text,
    });
  }
  return turns;
};
