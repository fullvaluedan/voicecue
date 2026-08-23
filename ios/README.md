# VoiceCue for iOS

A native wrapper that turns the VoiceCue web app into a real iPhone app. The prompter UI is
the same `index.html` that lives at the root of this repo — the project references it
directly, so there is only ever one copy to edit.

What the native side adds:

| | Browser | iOS app |
|---|---|---|
| Voice tracking | `webkitSpeechRecognition`, Safari only, sends audio to Apple's servers | `SFSpeechRecognizer`, on-device wherever the hardware supports it |
| Session length | Cut off after about a minute | Runs as long as you read |
| Fullscreen | Safari toolbar in the way | Owns the screen |
| Screen sleep | Wake Lock API is unimplemented in WebKit on iOS | Idle timer held while prompting |
| Fonts | Fetched from Google Fonts | Bundled; works in airplane mode |
| Scripts | `localStorage`, cleared when Safari evicts the site | `localStorage` on a stable app origin, with a native store as backstop |

## Building

Open `ios/VoiceCue.xcodeproj` in Xcode 15 or newer, pick the **VoiceCue** scheme, and run.

The Simulator has no microphone input worth testing against — run on a real device to try
voice tracking. To do that, select your iPhone as the destination, then under
**Signing & Capabilities** set your own team; the bundle identifier
(`com.fullvaluedan.voicecue`) may need to change if it is already taken on your account.

Minimum deployment target is iOS 16.

## How the bridge works

The web app already knows how to talk to a native recogniser — if
`window.webkit.messageHandlers.speech` exists, it swaps its `SpeechRecognition`
implementation for a shim that posts `start`/`stop` to the app and receives transcripts back
through `window.__nativeSpeech`. The native side just has to speak that protocol.

| File | Role |
|---|---|
| `SpeechBridge.swift` | Runs `AVAudioEngine` + `SFSpeechRecognizer` and reshapes its output into Web Speech API semantics |
| `PrompterViewController.swift` | Hosts the `WKWebView`, routes `speech` / `wake` / `store` messages |
| `BundleSchemeHandler.swift` | Serves the app from `voicecue://app/…` and points the page at the bundled fonts |
| `NativeStore.swift` | Disk-backed key/value store, used only if `localStorage` is unavailable |
| `Web/Bootstrap.js` | Injected before page scripts: wake-lock polyfill, storage fallback, hides browser-only controls |

### Transcript reshaping

This is the one genuinely fiddly part. `SFSpeechRecognizer` reports a **cumulative**
transcript that it keeps revising near the end, while the page expects the Web Speech
model: append-only final results plus a single replaceable interim one.

`SpeechBridge` treats everything older than the last five words as settled and emits it
once as a final chunk, then re-emits only the unsettled tail as the interim. Concatenating
what the page receives reproduces the recogniser's transcript exactly.

A recognition task can also die mid-session — silence timeouts, or the length limit that
applies when on-device recognition isn't available. The bridge starts a fresh task against
the same still-running audio tap, and settles the outstanding tail first, because those
words exist only as an interim result that the next task's first interim would erase.
