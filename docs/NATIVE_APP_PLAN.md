# VoiceCue native app plan: a teleprompter that floats over TikTok

Written 2026-11-21 on the Windows PC. Continue on the MacBook (Xcode is needed from Phase 0 on).

## Goal

A phone app where the VoiceCue script floats over TikTok (and Instagram, the stock Camera, any recording app)
while you record there, and still follows your voice. TikTok records from the camera, not the screen, so the
floating script never shows in the video.

Later, not now: an AI interview mode. Keep it out of this plan.

## Where things stand

- The web app is one file, `index.html`, live at https://fullvaluedan.github.io/voicecue/ (GitHub Pages, `main`).
- It already has: voice tracking, vertical and horizontal, Studio Camera recording inside VoiceCue (9:16 and
  16:9, takes, markers), script notes (`### headings`, `[react: ...]`, `**bold**`), a movable reading line,
  GitHub sign-in with gist sync (`auth-worker/` is the Cloudflare Worker for sign-in), share links, mirroring.
- A web page cannot draw over another app, and it loses the mic once TikTok is open. Floating needs a native app.
- Known web limit: on phones, voice tracking pauses while Studio Camera records, because the camera holds the mic.

## Who already does this

- VoicePrompter (iPhone): floats over TikTok and follows your voice, per its developer's own blog
  (https://konsu.dev/blog/floating-teleprompter-iphone/). That is the proof it can be done, and the main rival.
- Floating but fixed speed: Teleprompter Floating Notes, Teleprompt Overlay, ScriptCue, OmniCue.
- Voice tracking but only inside their own app: Teleprompter.com, PromptSmart.

What VoiceCue has that they do not appear to: calm tracking (ad-libs never move the script, only exact phrases
do), `[react]` notes and headings that tracking skips, write on desktop and read on the phone, scripts pushed
straight from the content pipeline.

## The two unknowns (Phase 0 answers them)

Everything else is ordinary app work. These two decide whether the product exists:

1. Does the floating window stay up when TikTok starts its camera? One developer on Apple's forum reports iOS
   ended their picture-in-picture session at that moment (https://developer.apple.com/forums/thread/815566).
   VoicePrompter says it works, so there is a way. Find it.
2. Does speech recognition keep hearing you while TikTok records? Two apps want the mic at once.

## Phase 0: test app on Dan's iPhone (1 to 2 days)

A throwaway Xcode project. No design, no accounts. Hard-code one script.

Build:
- A floating window using `AVPictureInPictureController` with an `AVSampleBufferDisplayLayer` content source
  (iOS 15+). Draw the script text into frames yourself. Background mode: Audio.
- Speech with `SFSpeechRecognizer`, `requiresOnDeviceRecognition = true`, partial results on. Audio session
  category `playAndRecord` with `mixWithOthers`. Restart the recognition task about every 50 seconds, since one
  task is time limited.
- Print each partial transcript in the floating window, so the phone screen itself shows whether it hears you.

Test on a real iPhone (the simulator has no picture-in-picture camera behaviour), in this order:
1. Start floating, open the stock Camera, record video. Window still up? Transcript still updating?
2. Same in TikTok: the record screen, then recording, then with an effect on.
3. Same in Instagram Reels.
4. TikTok Live, if the account can go live.
5. Lock and unlock the phone mid-take. Take a phone call. Does it recover?
6. Check the recorded TikTok video: no script visible, and the voice audio is not ducked or damaged.

Write the results into `docs/PHASE0_RESULTS.md`, one line per test: pass, fail, or what happened.

Decision after Phase 0:
- Both work: go to Phase 1.
- Window stays but speech goes deaf: ship floating with manual speed first, plus the existing Mirror feature
  (a second device listens and drives the scroll). Keep looking for the mic fix.
- Window dies when the camera starts and no setting fixes it: stop. Tell Dan. Do not build Phase 1.

## Phase 1: the iPhone app (1 to 2 weeks after Phase 0 passes)

Shape: a thin native shell around the existing web app, plus a native floating window.

- `WKWebView` loads the bundled `index.html`. Library, editor, settings, Studio Camera all stay web code.
- Speech bridge. The hook is already in `index.html` (search `NativeSR`, about line 759):
  - Web calls `window.webkit.messageHandlers.speech.postMessage({cmd:"start", lang})` and `{cmd:"stop"}`.
  - Native calls `window.__nativeSpeech.result(transcript, isFinal)`, `.error(code)`, `.ended()`.
  - Inside the app this also removes the web limit above: native speech and the camera can share the mic.
- Floating mode. A "Float over other apps" button on the prompter.
  - The floating window is drawn natively, so the matching has to run natively too (the web view may be
    suspended in the background). Port to Swift: `normWord`, `simWords`, `lev`, `suffixMatch`, `matchSpoken`,
    the `COMMON` and `FILLERS` lists, and the note-skipping parse in `buildContent`. About 200 lines.
  - Keep the rules identical: 2 exact words to step forward, 4 exact words for any bigger move, common words
    are not proof, the search window never widens.
  - Port the tests first. `window.__vc.feed("words")` and `__vc.state().pos` are the web test hooks. Take the
    cases from the 2026-11-16 commits (reading, freestyle full of script words holds, retake jumps back,
    misheard words still track) and make the Swift matcher give the same positions.
  - In the window: current line large, a couple of lines above and below, reading line marker, text size.
  - Picture-in-picture windows cannot take taps on custom buttons. Control it by voice ("go back", "go to
    start") or by the system skip buttons. Decide after trying both on the phone.
- Sign-in. Creators will not have GitHub. Add Sign in with Apple (required by App Store rules once any other
  sign-in is offered) and Google. Scripts then need our own storage: Cloudflare Worker plus D1 or KV, next to
  `auth-worker/`. Keep GitHub gist sync working for Dan's existing scripts, or write a one-time import.
- Privacy strings: microphone, speech recognition, camera.

## Phase 2: launch as a service

- Check the name first. "VoiceCue" is close to VoicePrompter, and there may be other VoiceCue apps. Search the
  App Store and the USPTO trademark database before paying for anything.
- Apple Developer Program: 99 dollars a year. Dan enrolls (it needs his Apple ID and payment).
- Pricing to test: free with 3 scripts and full voice tracking (VoicePrompter's free tier is the bar), paid
  for unlimited scripts, sync, floating. Use StoreKit subscriptions. Numbers are Dan's call.
- App Store listing: the pitch is "reads along with you over TikTok, and never runs off when you ad-lib".
  Screen recording of it floating over TikTok is the first screenshot.
- TestFlight with a few creators before public release.
- A landing page. The web app stays the free way in and links to the App Store.

## Phase 3: Android

Do it after the iPhone app ships.

- Floating is easier: the "display over other apps" permission (`SYSTEM_ALERT_WINDOW`) and a foreground service.
- The mic is harder. On Android 10 and later, when two ordinary apps record at once, the one on screen gets
  the audio and the other gets silence. TikTok would be on screen. Expect voice tracking to go deaf while
  TikTok records, and test that before promising it. Manual speed and Mirror are the fallback.

## Rules for whoever continues this

- `index.html` on `main` is the live site. Every push deploys in about a minute. Test before pushing.
- Put the native project in `ios/`. Keep `index.html` at the repo root so GitHub Pages keeps working.
- Local preview on Windows: `python -m http.server 4480 --directory D:/Claude/voicecue`. On the Mac, the same
  from the repo folder.
- Secrets never go in the repo. The sign-in Worker's secrets live in Cloudflare (`wrangler secret put`).
- Ask Dan before anything that costs money or creates an account.

## First steps on the MacBook

1. `git clone https://github.com/fullvaluedan/voicecue` and open this file.
2. Install Xcode if it is missing. A free Apple ID is enough to run a test app on Dan's own iPhone for 7 days
   at a time, so Phase 0 does not need the paid developer account.
3. Build the Phase 0 test app in `ios/Phase0/`, run the 6 tests on the iPhone, write `docs/PHASE0_RESULTS.md`.
4. Report the result to Dan in plain words before starting Phase 1.
