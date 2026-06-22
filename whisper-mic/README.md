# whisper-mic

Real-time microphone transcription on Apple Silicon, powered by
[whisper.cpp](https://github.com/ggml-org/whisper.cpp) running the
`large-v3-turbo` model on the GPU (Metal) + Apple Neural Engine (Core ML).

This directory is a **thin wrapper**. The actual engine, build, and model live
in `~/whisper.cpp` (kept out of this repo — it's multi-GB). `mic.sh` just
launches the `whisper-stream` binary with live-mic defaults.

## Use

```bash
./mic.sh                 # auto-detect language, VAD sliding-window mode
./mic.sh -l en           # pin English
./mic.sh -tr             # translate to English
WHISPER_STEP=500 ./mic.sh   # fixed 500ms chunks instead of VAD
```

Speak; partial transcripts print live. `Ctrl-C` to stop.

## ⚠️ Microphone permission

`whisper-stream` captures via SDL2. If you get **silence / no output**, grant
your terminal app mic access:

**System Settings → Privacy & Security → Microphone** → enable your terminal
(Terminal / iTerm / Ghostty / VS Code / Cursor). Restart the terminal after.

This is the #1 reason it appears "broken."

## Config (env vars)

| Var | Default | Meaning |
|-----|---------|---------|
| `WHISPER_DIR` | `~/whisper.cpp` | engine + model location |
| `WHISPER_MODEL` | `…/ggml-large-v3-turbo.bin` | model file |
| `WHISPER_STEP` | `0` | audio step ms; `0` = VAD sliding window (best quality) |
| `WHISPER_LENGTH` | `30000` | max window ms in VAD mode |
| `WHISPER_VAD` | `0.6` | voice-activity threshold |
| `WHISPER_THREADS` | `8` | CPU threads |
| `WHISPER_LANG` | `auto` | language code, or `auto` |

Any extra args pass straight through to `whisper-stream`
(`./mic.sh --help` for the full list).

## Acceleration

- **Metal** (GPU): on by default — inference runs fully on GPU.
- **Core ML** (ANE): encoder runs on the Neural Engine, >3x faster encode.
  Requires `models/ggml-large-v3-turbo-encoder.mlmodelc` in `~/whisper.cpp`
  (generated via `models/generate-coreml-model.sh`). First run is slow while
  the ANE compiles the model; later runs are fast.
- `-fa` (flash attention) is enabled by default in `mic.sh`.

## Rebuild / update the engine

```bash
cd ~/whisper.cpp
git pull
cmake -B build -DWHISPER_COREML=1 -DWHISPER_SDL2=ON
cmake --build build -j --config Release
```

The Metal backend improves often — pull + rebuild periodically.
