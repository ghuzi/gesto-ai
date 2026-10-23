# Gesto AI — Android app (Flutter)

The native Android client for **Gesto AI**: Pakistan Sign Language → Urdu speech,
in real time. It reuses the exact same backend and wire protocol as the web app
(`chat-1/gesto-ai/frontend/script.js`), so both clients can talk to the same
Railway server.

| | |
| --- | --- |
| Package | `ai.gesto.app` |
| Min Android | 7.0 (Flutter default) |
| Built with | Flutter stable · Dart 3 · Material 3 |
| Backend | `https://gesto-backend-production.up.railway.app` (changeable at runtime) |

## Download the APK

**[⬇ Download the latest APK](https://github.com/ghuzi/gesto-ai/releases/latest)**

Scan with your phone to open the download page:

<img src="docs/apk-qr.png" alt="QR code to the Gesto AI APK releases" width="170" />

Then pick one file:

| File | Use it for |
| --- | --- |
| `gesto-ai-<version>-universal.apk` | Any Android phone (safest, ~58 MB) |
| `gesto-ai-<version>-arm64-v8a.apk` | Modern 64-bit phones (~24 MB) |
| `gesto-ai-<version>-armeabi-v7a.apk` | Older 32-bit phones (~21 MB) |
| `gesto-ai-<version>-x86_64.apk` | Emulators |

**Install:** open the downloaded file → Android asks to allow installs from your
browser/file manager → *Allow* → *Install*. Android 7.0+ required. Releases are
signed with the debug key, so Play Protect may show a "scan" prompt — choose
*Install anyway*.

* **v1.0.3 and later install over each other** — the repo carries a shared
  `android/app/debug.keystore`, and CI asserts every APK is signed with it.
* Coming from v1.0.0–v1.0.2 (built with a per-run key), uninstall the old app
  **once**; after that updates are in-place.

To build a new release: `git tag android-v1.0.3 && git push origin android-v1.0.3`
(bump `version:` in `pubspec.yaml` first). The tag push builds and uploads the
APKs automatically.

## Server unreachable?

The app never crashes when the backend is down — the Home card shows what went
wrong, keeps retrying on its own (15 s → 30 s → 60 s) and offers **Change server**.

* `HTTP 404 — no backend is deployed at this address` → wrong/deleted host.
  Tap **Change server** (or **Settings → Backend server**) and paste the live URL.
* `HTTP 502/503` or a timeout → the free instance is waking up; wait a minute.
* No internet → fix Wi-Fi/mobile data.

**v1.0.2 auto-heals old installs:** if the saved server is one of the retired
hosts (`gesto-ai-production.up.railway.app` and friends) it is replaced with the
current live backend on start-up — no Settings trip needed.

## What the app does

1. **Live Demo** — opens the camera, streams ~10 JPEG frames/second over
   `wss://…/ws/predict`, shows the recognised PSL gesture, its Urdu script and
   the Urdu sentence returned by the backend, and speaks it aloud.
2. **History** — every stable gesture is saved locally (SharedPreferences) with
   time and confidence; filterable, replayable with one tap.
3. **Settings** — UI language (English / اردو), backend URL, speech on/off and
   speed, TTS voice check, clear history.
4. **About** — the problem, the pipeline, the tech stack, the team, and links.

Everything works offline except recognition itself (the model lives on the
server). The server address can be changed at runtime, so you can point the app
at `http://<your-laptop-ip>:8000` for an offline demo on the same Wi-Fi.

## Build the APK

### Option A — GitHub Actions (no Android SDK needed)

Every push that touches `mobile/**` builds the APK on GitHub's runners:

* **Actions → Build Android APK → latest run → Artifacts → `gesto-ai-apk`**
* Or run the workflow manually (**Run workflow**, `make_release = true`) to get a
  public download link under **Releases → `android-v1.0.0-<build>`**.

### Option B — locally

```bash
cd mobile
flutter pub get
flutter build apk --release            # build/app/outputs/flutter-apk/app-release.apk
flutter build apk --release --split-per-abi   # smaller per-CPU APKs
```

Requires Flutter 3.47+ (pinned in CI) and JDK 17. `flutter doctor` should show the
Android toolchain as ready.

### Release signing (optional)

`android/app/build.gradle.kts` signs release builds with the debug key so the
APK installs out of the box. For a Play Store build, create a keystore and add
`mobile/android/key.properties`:

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

The Gradle file picks it up automatically (and `key.properties` / `*.jks` are
git-ignored).

## Run on a device

```bash
flutter devices
flutter run -d <device-id>
```

Camera + microphone permissions are requested on first use; the app also opens
Android's app settings if the permission was permanently denied.

## Custom backend

```bash
# baked into the build
flutter build apk --dart-define=GESTO_API_BASE=http://192.168.1.10:8000
```

or at runtime: **Settings → Backend server → Test connection → Save**.

For CI builds, set the repository variable `GESTO_API_BASE` (Settings → Secrets
and variables → Actions → Variables) — `Build Android APK` passes it as
`--dart-define`, so every new APK already points at the right server.

For plain `http://` (LAN demos) the manifest already enables cleartext traffic.

## Protocol (unchanged from the web client)

```jsonc
// client → server
{"frame": "<base64 JPEG without data-url prefix>"}

// server → client
{"gesture": "help" | null, "confidence": 0.93, "reason": "no_hand|warming_up|below_threshold|not_ready|decode_failed", "sentence": "مجھے مدد چاہیے"}
```

The app never mirrors the frames it sends — the model sees exactly what the
camera captured, matching the training pipeline.

## Project layout

```
chat-1/gesto-ai/mobile/
├── lib/
│   ├── app/          # theme, localisation (en/ur), AppState, config
│   ├── data/         # gesture → Urdu / Devanagari maps, default labels
│   ├── models/       # Prediction, GestureEvent, BackendHealth
│   ├── services/     # HTTP + WebSocket client, frame encoder, TTS
│   ├── screens/      # onboarding, home, demo, history, settings, about
│   └── widgets/      # cards, confidence bar, scanline, brand mark…
├── assets/team/      # team photos (same files as the web app)
└── android/          # Gradle project (AGP 9.1, Kotlin 2.4, Gradle 9.3)
    └── app/src/main/kotlin/ai/gesto/app/MainActivity.kt
                        # YUV_420_888 → NV21 → JPEG method channel
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| “Server unreachable” | Railway free instances sleep — open the web demo once to wake it, then tap **Check again**. |
| “Model not loaded” | The backend started without the `.h5` / `.pkl` / `.task` files. See the root README. |
| No sound | Install an Urdu or Hindi TTS voice in Android settings → Languages → Text-to-speech. Settings shows which voice the app found. |
| Camera black screen | Another app is holding the camera, or the emulator has no camera. Use a physical phone. |
| *"0 frames sent"* / “Could not read a camera frame” | Fixed in v1.0.3. Android has no JPEG image stream — the app now asks for YUV_420_888 and converts it to JPEG natively (`ai.gesto.app/camera_codec`). Update to the latest APK. |
