# TimberVox TODO

This is the canonical active work list. Completed work belongs in [`../CHANGELOG.md`](../CHANGELOG.md); [`REBUILD.md`](REBUILD.md) holds the durable product and architecture roadmap.

## Now: close the cloud-dictation alpha

### Runtime reliability

- [ ] Run a hands-on default-microphone disconnect/reconnect acceptance when convenient. Bluetooth format changes are later device-matrix coverage and do not block the cloud-dictation alpha without the hardware.
- [ ] Exercise system-audio denial/revocation/re-grant, network interruption, and quit/relaunch recovery. Confirm the permission evidence flag changes only after non-silent system capture.
- [ ] Human-check the remaining playback paths: Mute during a real dictation and Pause with Music or Spotify, including the first Automation permission prompt. Verify the release entitlement/justification before App Store submission.

### Prompt, context, and persistence

- [ ] Run controlled macOS context acceptance and save inspectable artifacts: application/window/focused text, selected text, clipboard inside and outside the three-second pre-recording boundary, clipboard changes during recording, and copied file/image metadata.
- [ ] Run screen-only OCR acceptance with a sentinel Accessibility cannot read. Verify disabled/denied behavior, local screenshot cleanup, and that only OCR text plus attachment metadata reaches the transform request.
- [ ] Persist the exact context snapshot, transform request, transform response metadata, and attachment references with each dictation run. Raw and final text are already stored, but a run is not yet fully reproducible from the database.
- [ ] Run one complete transformed dictation from recording through real provider, paste delivery, saved raw/final text, saved context, and History inspection.

### macOS behavior acceptance

- [ ] Cold-launch and verify Microphone, Accessibility, Screen Recording, and System Audio Recording independently, including denial, Settings recovery, revocation, and re-grant.
- [ ] Verify global toggle, stop, and cancel while the main TimberVox window is closed.
- [ ] Verify paste and clipboard restoration in TextEdit plus a browser/editor while TimberVox remains inactive.
- [ ] Verify the passive recording indicator never activates TimberVox or steals focus.
- [ ] Verify History survives quit/relaunch, search finds a saved run, playback works, and rerun retains lineage instead of appearing as an unrelated dictation.

### Production UI integration

- [ ] Treat `Features/Prototype` as design evidence only. Modes is now promoted against the real mode store and Worker catalog; select and connect the accepted Home, History, Settings, onboarding, and remaining navigation shapes before replacing those production views.
- [ ] Remove sample-only behavior from every promoted surface. Transcriptions, Meetings, and Commands must remain absent from production navigation until their runtime paths exist.
- [ ] Split production History into list, detail, playback, and rerun responsibilities; use native `.searchable` and show raw/final text, mode, source app, provider/model, language, latency, context, and failures truthfully.
- [ ] Visually verify the connected production window at supported sizes, light/dark appearance, empty/loading/error/populated states, keyboard navigation, and VoiceOver labels.

## Next: local models

- [ ] Connect the implemented local package lifecycle to production UI: show missing, partial, downloaded-but-unverified, downloading, ready, and failed states; show combined package size/progress; offer prepare/verify and reference-aware deletion.

## Then: durable transcription and meetings

- [ ] Expand GRDB into audio items, linked transcription runs, timed segments/words, speakers, context snapshots/attachments, artifacts, errors, manual-rerun lineage, and FTS.
- [ ] Port TXT, Markdown, JSON, SRT, and WebVTT export with generated-artifact verification. Add HTML/PDF/DOCX only when implemented and visually checked.
- [ ] Build File Transcription before Meetings: import, progress, cancellation, editing, speaker renaming, playback seeking, rerun, persistence, and export using the existing direct-R2 path.
- [ ] Build Meetings on the accepted microphone-plus-system capture: retained stems/master, checkpoints, provisional realtime text, final batch reconciliation, and summaries generated only from the final transcript.
- [ ] Run the existing AMI two-speaker fixture, a multipart-sized file, and a 10–15 minute live meeting through interruption, quit/relaunch, reconciliation, editing, and export.

## Cloud and billing before release

- [ ] Add static-API-key-scoped upload/transcription rate limits and usage quotas grounded in actual provider and R2 constraints.
- [ ] Repair RevenueCat Test Store products/packages in the app, verify $7.99 monthly and $19.99 lifetime, then accept purchase success/cancel/failure, restore, and universal purchase after the iOS app exists. RevenueCat does not provision or authorize Worker access.
- [ ] Revalidate the App Store Connect Team API key after Apple's upstream `401 NOT_AUTHORIZED` clears; do not generate more keys merely to chase propagation.
- [ ] Add App Review metadata/screenshots and verify the release sandbox, signing, Apple-events behavior, and RevenueCat production key.
- [ ] Rotate the exposed Cloudflare API token and R2 S3 credentials, replace Worker secrets with bucket-scoped credentials, rotate the static TimberVox API key set, and rerun direct-upload smoke.

## Later product slices

- [ ] Sound feedback as a complete settings-and-runtime slice.
- [ ] Hot mic and push-to-talk with explicit buffer, permission, and cancellation semantics.
- [ ] Vocabulary/dictionary integrated into actual context capture and transform acceptance.
- [ ] Voice Commands only after command recognition, confirmation, execution, persistence, and recovery exist outside the prototype.
