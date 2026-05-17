# Radical Resolve

Local-first radical acceptance companion. iOS-first Flutter app that runs a
Gemma 4 E4B GGUF (fine-tuned with the Helios distillation pipeline) entirely on
device via `fllama` (llama.cpp + Metal). No conversations leave the phone.

## Architecture

```
lib/
├── main.dart                          # ProviderScope + RadicalResolveApp
├── app.dart                           # Material root, home screen, SOS button
├── config/
│   ├── model_config.dart              # GGUF URL, sha256, size, ctx, gpu layers
│   └── app_config.dart                # App-level constants
├── core/
│   ├── inference/
│   │   ├── llm_engine.dart            # Abstract engine interface
│   │   ├── fllama_engine.dart         # fllama implementation (Metal on iOS)
│   │   ├── inference_service.dart     # Conversation StateNotifier + mode listener
│   │   └── engine_lifecycle.dart      # FutureProvider that downloads + loads
│   ├── prompts/
│   │   ├── prompt_asset.dart          # Immutable JSON-backed PromptAsset
│   │   └── prompt_registry.dart       # Loads bundled assets/prompts/*.json
│   ├── model_download/
│   │   ├── model_storage.dart         # Where the .gguf lives on disk
│   │   └── model_downloader.dart      # R2 download w/ resume + sha256
│   └── state/
│       ├── app_mode.dart              # enum AppMode { idle, sos, journal, ... }
│       ├── app_mode_controller.dart   # StateNotifier<AppMode>
│       └── conversation_state.dart    # Turns + streaming buffer
├── features/
│   ├── sos/sos_screen.dart            # Implemented — demonstrates hot-swap
│   ├── journal/                       # Stub for MacBook to flesh out
│   ├── lessons/                       # Stub
│   └── chat/                          # Stub
└── widgets/                           # Empty
assets/
└── prompts/
    ├── sos_grounding.json             # Agent A — Compassionate Listener
    ├── analytical_planner.json        # Agent B — Analytical Planner
    └── lesson_companion.json          # Lesson reinforcement agent
```

## How the hot-swap works

1. UI calls `ref.read(appModeControllerProvider.notifier).enterSos()`.
2. `AppModeController` flips `state` to `AppMode.sos`.
3. `InferenceService` is subscribed to the mode stream. On change:
   - Cancels any in-flight generation (`_engine.cancel()`).
   - Looks up the new `PromptAsset` by `mode.promptId`.
   - Resets `ConversationState` to a fresh seed with the new opener.
4. Next `sendUserMessage` uses the new system prompt + generation params.

Prompts are immutable JSON shipped in the app bundle — A/B variants can be
hot-pushed by replacing the JSON in an over-the-air asset bundle without an
App Store update (future work).

## Model delivery

- The `gemma-4-e4b-radical-resolve-v1-q5_k_m.gguf` is **not** bundled in the IPA.
- On first launch `engineReadyProvider` resolves `modelInstallProvider`, which
  pulls the GGUF from Cloudflare R2 with `Range:` resume and verifies sha256.
- Stored in `getApplicationSupportDirectory()/models/`.
- `AppConfig.requireWifiForDownload` should be enforced in the download UI
  (TODO when the download screen is built).

## What needs filling in

- `ModelConfig.gemma4E4bRadicalResolveV1.sha256` — replace
  `TBD_FILLED_AFTER_TRAINING_CONVERT` after Helios trains, quantizes, and
  uploads the GGUF to R2.
- `ModelConfig.gemma4E4bRadicalResolveV1.downloadUrl` — replace with the real
  R2 public URL.
- `features/journal`, `features/lessons`, `features/chat` screens — translate
  from the existing PWA at `~/radicalacceptance-website/public/`.
- iOS Podfile changes for `fllama` (Metal linker flags) — see fllama README.
- Donation flow (Stripe / Apple IAP) — separate decision.

## Compute fleet roles

- **Claude (Helios)** — architecture, scaffolding, prompt assets, fllama
  interface, state machine.
- **MacBook Pro + Qwen Coder 80B** — translate PWA JS/Supabase screens into
  Dart, build out `features/journal`, `features/lessons`, `features/chat` from
  `~/radicalacceptance-website/public/`.
- **Helios rig** — Unsloth SFT on Gemma 4 E4B with the 6,333 pillar-tagged
  moment cards (excluding LNT tokenomics; including curated
  community/kindness slice).

## Running

```
cd ~/radical-resolve
flutter pub get
flutter run -d <ios-device-id>
```

`fllama` requires iOS 14+. Tested target: iPhone 17 Pro Max.
