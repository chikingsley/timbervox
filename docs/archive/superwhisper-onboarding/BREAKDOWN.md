# Superwhisper onboarding — full breakdown

Archived for reference while we redo TimberVox onboarding. This walks their flow screen by
screen: what's on screen, what moves, and what it's probably doing under the hood. At the end:
how it compares to what we have today, and a list of decisions for you to make.

Everything here is read off the recordings and screenshots in this folder. The "under the hood"
notes are educated guesses, marked as such — not confirmed.

---

## Source files (what maps to what)

| File | What it is |
|---|---|
| `install mac thing.png` | The DMG drag-to-install window (before the app ever opens) |
| `screen1.png` | Onboarding screen 1 — Welcome |
| `screen2.png` | Onboarding screen 2 — Permissions |
| `screen3.png` | Onboarding screen 3 — Microphone test |
| `superwhisper-onboarding-main.mov` | The middle of onboarding (mic test → paywall → model choice → download). ~6.8 min, but the real content is the first ~65s; the rest is the empty window sitting there. |
| `superwhisper-onboarding-try-shortcut.mov` | The final "try the shortcut" step |
| `superwhisper-large-pill.mov` | The big recording HUD ("pill") in use |
| `superwhisper-small-pill.mov` | The minimal recording HUD ("pill") in use |
| `stills/` | Clean full-size frames I pulled out of the videos so you don't have to scrub them |

---

## The flow at a glance

0. **Install** — drag the app into Applications from a branded DMG
1. **Welcome**
2. **Permissions** — mic + accessibility
3. **Microphone test** — talk, watch the waves move
4. **Paywall** — "Unlock all Pro Features" with a scrolling feature carousel
5. **Choose your model** — Cloud vs Local
6. **Download model** — only if you picked Local (downloads Parakeet)
7. **Try the shortcut** — you have to actually dictate one sentence before you can finish
8. Window closes → app lives in the menu bar, and from now on you only see the **pill**

One centered floating card the whole time — dark, rounded corners, soft glow around it. A thin
glowing blue progress bar sits along the top and fills as you move through steps (it doesn't
appear until after Welcome). Every step has one obvious primary button at the bottom.

---

## Step 0 — Install (the DMG)

**File:** `install mac thing.png`

A custom disk-image window. Background is a wide horizontal audio-waveform graphic with a big
play triangle in the middle. The Superwhisper icon sits on the left labeled "superwhisper"; the
Applications folder sits on the right (with an App Store badge and an alias arrow). Caption across
the bottom: **"To install, drag superwhisper to Applications."** Standard Mac install gesture,
just dressed up with their artwork.

- **Why not the App Store:** the app needs Accessibility access to paste into other apps and a
  system-wide hotkey. Sandboxed App Store apps can't really do that, so they ship a notarized DMG
  you download from their site and drag in. (This is the thing you mentioned — most people know
  the drag-to-Applications move by now, but it's still a step.)
- **Likely tech:** notarized Developer-ID build, custom `.dmg` background image, probably
  Sparkle for auto-updates afterward.

**Chi's take:** _(like / dislike / notes)_

---

## Step 1 — Welcome

**File:** `screen1.png`

- **Title:** "Welcome to Superwhisper"
- **Body:** "We'll guide you through set up and make sure Superwhisper works the way you want."
- Greyed line: **"Estimated time: less than 2 minutes"** — sets expectations, lowers the "ugh, setup" feeling.
- Full-width blue **Get Started** button.
- Small link at the very bottom: **"My company uses Superwhisper"** — a separate path for people
  whose org already pays / manages a license.
- **What moves:** the black background has a subtle animated abstract — soft light ribbons /
  lens-flare streaks drifting slowly. No progress bar yet on this screen.

**Chi's take:** _(like / dislike / notes)_

---

## Step 2 — Permissions

**File:** `screen2.png`

- Progress bar appears, ~15% filled.
- **Title:** "Let's set up permissions"
- Blue link right under it: **"Learn how privacy is at the heart of Superwhisper ›"**
- Two rows, each with an icon, a name, a plain-English reason, and a status on the right:
  - 🎤 **Allow Microphone Access** — "Required to capture audio for transcription. Only used when
    dictation is active." → **✓ Allowed**
  - ⓘ **Allow Accessibility Access** — "Required to paste text into apps & interact with your
    system. Only used when needed." → **✓ Allowed**
- Full-width blue **Continue**.
- In the recording both already show "✓ Allowed." Before you grant them, this is presumably a
  "Grant" / "Enable" affordance that flips to the checkmark once macOS confirms.

- **Likely tech:** microphone via `AVCaptureDevice.requestAccess(.audio)`; accessibility via
  `AXIsProcessTrustedWithOptions` (which pops the "open System Settings → Privacy → Accessibility"
  prompt). The page almost certainly re-checks status when you come back to the app so the
  checkmarks update on their own.

**Chi's take:** _(like / dislike / notes)_

---

## Step 3 — Microphone test

**File:** `screen3.png`, and the first seconds of `superwhisper-onboarding-main.mov`

- Progress ~30%.
- **Title:** "Let's test your microphone"
- Body: "Speak and see if the waves react. No response? Try changing your input device below."
- Blue **"System default 🎧"** input-device picker (tap to switch mics).
- A live waveform histogram (grey vertical bars) filling the lower half.
- **What moves:** the bars react to your actual voice in real time — immediate proof the mic
  works, and a reason to say something out loud before it matters.
- Full-width blue **Continue**.

- **Likely tech:** `AVAudioEngine` tap on the input, bars drawn from the audio level (RMS) of each
  buffer, in a SwiftUI Canvas or similar.

**Chi's take:** _(like / dislike / notes)_

---

## Step 4 — Paywall ("Unlock all Pro Features")

**Files:** `stills/05-paywall-pro.png`, `stills/05-paywall-pro-cloudcards.png`

- Progress ~⅓.
- **Title:** "Unlock all Pro Features" — subtitle "Advanced tools for a refined workflow."
- A row of rounded feature cards that **auto-scrolls sideways** — a slow, continuous marquee. The
  cards I could read as it went by:
  - Transcribe video and audio files
  - Unlimited modes
  - All Local Models (chip icon)
  - **Translate any language to English** — this card animates greetings cycling through many
    languages: hello / こんにちは / привет / aloha / 안녕하세요 / bonjour / labas / olá …
  - 30 Days Money-back guarantee
  - Priority support
  - Unlimited use of Cloud models (infinity-cloud icon)
  - Use your own API keys (keys icon)
- Three stacked actions:
  - Blue **Get Superwhisper Pro**
  - Muted **I already have a license**
  - Text link **Maybe later**
- **What moves:** the whole card strip glides left forever; the translate card cycles greetings.
  It reads as "look how much this does" without a wall of text.

- **Note:** this is a sell screen dropped in the middle of setup. "Maybe later" lets you skip it,
  so it doesn't hard-block onboarding. Their pricing is a paid Pro tier (subscription or lifetime)
  plus a bring-your-own-API-key option.

**Chi's take:** _(like / dislike / notes)_

---

## Step 5 — Choose your model (Cloud vs Local)

**Files:** `stills/06-model-cloud.png` (Cloud selected), `stills/06-model-local.png` (Local selected)

- Progress ~½.
- **Title:** "Select your preferred model"
- Two big tiles side by side. The selected one gets a glowing blue border.
  - **Cloud** (cloud icon)
  - **Local** (wifi-slash icon)
- The subtitle *and* the button change depending on which you pick:
  - **Cloud** → "Faster performance with internet connection required. Your recordings go to the
    cloud to process but are never stored there." → button says **Continue**.
  - **Local** → "Works offline with complete privacy. Best choice for newer Macs with more
    processing power." → button changes to **Download**.
- Blue link: **"Learn how privacy is at the heart of Superwhisper ›"**
- **What moves:** the selection highlight animates between the two tiles as you click.

- **Nice detail:** the button label itself tells you what happens next (Continue vs Download), so
  there's no surprise download.

**Chi's take:** _(like / dislike / notes)_

---

## Step 6 — Download model (Local path only)

**File:** `stills/07-downloading-parakeet.png`

- Progress ~⅗.
- **Title:** "Downloading Parakeet"
- Body: "Parakeet will be set as your default voice model. You can always change this later in settings."
- Centered NVIDIA **Parakeet** logo (green).
- Buttons: **Back**, and a disabled **Please wait…** (it's the primary button, greyed out while the
  model downloads).
- **What this is:** Parakeet is NVIDIA's speech-recognition model. On Apple Silicon it runs
  on-device on the Neural Engine (via a CoreML pipeline), which is why "Local" has to download it
  first. It's fast — roughly ~80ms, and the newer version is multilingual (~25 languages). If you'd
  picked Cloud, this step doesn't happen; you go straight on.

**Chi's take:** _(like / dislike / notes)_

---

## Step 7 — Try the shortcut (the gated finish)

**Files:** `stills/08-try-shortcut-before.png`, `stills/08-try-shortcut-after.png`

- Progress ~90%.
- **Title:** "Try the shortcut"
- Instruction: **"Press and hold `Right ⌘` and start speaking"** (the key is drawn as a little
  keycap chip — note it's Right **Command** here, not Option; it's configurable).
- Blue link: **⌨ Change shortcut**
- A large text field with a focus ring and placeholder: *"Say 'This is my first recording with
  Superwhisper'"*.
- **Complete onboarding** button at the bottom, **greyed out / disabled** to start.
- **What moves / the key idea:** you *can't* finish until you actually dictate. When you hold the
  key and speak, your words stream into the field live ("Okay, yes, okay this works"), and only
  then does **Complete onboarding** turn blue and become clickable. It forces one successful
  end-to-end run — mic → transcribe → text on screen — before it lets you out. Best part of the flow.

**Chi's take:** _(like / dislike / notes)_

---

## After onboarding — the pill (recording HUD)

Once the window closes, the app lives in the menu bar and the only thing you normally see is the
**pill** — the little floating bar that appears while you're dictating. There are two sizes.

### Large pill

**File:** `stills/09-large-pill.png` (and `superwhisper-large-pill.mov`)

A wide rounded-dark bar with, left to right:
- 🎤 **Default** — the active input device
- a big **live scrolling waveform** in the center (real-time, scrolls as you talk)
- keyboard hints on the right: **Stop `⌥ Space`** and **Cancel `esc`**
- a small expand/collapse chevron in the corner

When you stop, it switches to a finalize state ("Default … Close `esc`", greyed) while it wraps up.
This is the detailed/verbose HUD.

### Small pill

**File:** `stills/10-small-pill.png` (and `superwhisper-small-pill.mov`)

The minimal version. A small black rounded pill anchored near the bottom of the screen. At rest
it's just a thin short bar (barely there). When you speak it grows a tiny cluster of reactive
vertical bars; between recordings it shrinks back down. Deliberately unobtrusive.

**Chi's take on the pills:** _(like / dislike / notes)_

---

## Probable tech stack (best guess, consolidated)

- **App:** native macOS, Swift + SwiftUI/AppKit. Notarized Developer-ID DMG (not App Store),
  auto-update likely via Sparkle.
- **Hotkey:** a global key monitor / event tap for push-to-talk (hold `Right ⌘` here; also supports
  press-to-toggle and remapping).
- **Audio + waveform:** `AVAudioEngine` tap; the waveforms are drawn from live audio levels.
- **Permissions:** mic = `AVCaptureDevice.requestAccess`; accessibility = `AXIsProcessTrusted…`.
- **Pasting into other apps:** put the transcript on the clipboard and synthesize ⌘V (or insert via
  the Accessibility API at the cursor). That's the "interact with your system" permission.
- **Local transcription:** on-device models — Whisper family (tiny → large-v3-turbo) and NVIDIA
  **Parakeet** running on the Apple Neural Engine via CoreML. Local = download the model first.
- **Cloud transcription:** audio sent to their server, "never stored"; also a bring-your-own-API-key
  option.
- **The real product after setup:** custom **Modes** — each Mode is a saved combo of a hotkey + a
  model + an optional AI cleanup prompt + rules for which app it auto-activates in. Onboarding
  deliberately hides all of that and just gets you to your first working dictation.

---

## Theirs vs. what we have today

Our current flow (from `TimberVox/Features/Onboarding/`): **Welcome → Permissions → First
dictation → Complete**, in one floating window, with a "Set Up Later" link in the corner, dot-style
progress, and a Continue / Open-TimberVox button.

| Step | Superwhisper | TimberVox today |
|---|---|---|
| Install screen | Branded DMG with waveform art | — (not addressed here) |
| Welcome | Title + "less than 2 min" + animated bg + enterprise link | Title + one-line pitch, waveform symbol |
| Permissions | Mic + Accessibility, plain reasons, auto-updating checks, privacy link | Mic + Accessibility with Grant buttons, auto-refresh ✅ (close parity) |
| Mic test | Dedicated "watch the waves" step + device picker | — (none) |
| Paywall | Scrolling feature carousel | — (different business; may not want one) |
| Choose model | Cloud vs Local, copy + button change per choice | — (none) |
| Download model | Downloads Parakeet for Local | — (none) |
| Try the shortcut | **Gated** — must dictate before finishing | **Gated** — must dictate + see it paste ✅ (same idea) |
| Progress | Glowing top bar that fills | Row of dots |
| Escape hatch | "Maybe later" on paywall only | "Set Up Later" always visible |
| Shortcut | Hold `Right ⌘`, changeable inline | `⌥ Space`, no inline change |

**Where they're clearly ahead (and worth stealing the idea, not the pixels):**
- The **mic test** as its own beat — cheap confidence, and it makes you talk before it counts.
- The **top progress bar that fills** reads as more "guided" than our dots.
- **Change shortcut inline** on the try step.
- The overall **polish**: one animated card, one primary button, plain reasons under each ask.

**Things they do that we may *not* want:**
- The **paywall mid-onboarding** — depends on our pricing model.
- The **Cloud vs Local + model download** — only matters once we actually offer both. Right now our
  build order is cloud-dictation-first, so this can wait.

---

## Decisions for you (fill in when we talk)

1. Do we want a dedicated **mic-test step**, or fold the waveform into the try-the-shortcut step?
2. Switch our progress **dots → a filling top bar**?
3. Add **"Change shortcut" inline** on the try step? (and what's our default key — `⌥ Space` vs a hold key)
4. Do we ever want a **Cloud/Local model choice** screen, and if so, when in the build?
5. Any **paywall / license** step at all, or keep onboarding purely functional for now?
6. Do we care about a **branded DMG** install screen, or is that later polish?
7. Which **pill** style is our default — the verbose one, the minimal one, or both with a setting?

_Add likes/dislikes inline under each "Chi's take" above, and we'll turn the keepers into a plan._
