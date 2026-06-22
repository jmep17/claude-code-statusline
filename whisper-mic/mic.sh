#!/usr/bin/env bash
# Real-time microphone transcription via whisper.cpp (whisper-stream).
# Thin wrapper: the engine + model live in $WHISPER_DIR (default ~/whisper.cpp),
# this script just launches the stream binary with sensible live-mic defaults.
set -euo pipefail

# --- config (override via env) ---
WHISPER_DIR="${WHISPER_DIR:-$HOME/whisper.cpp}"
MODEL="${WHISPER_MODEL:-$WHISPER_DIR/models/ggml-large-v3-turbo.bin}"
BIN="$WHISPER_DIR/build/bin/whisper-stream"

# live-mic tuning (override via env)
STEP="${WHISPER_STEP:-0}"          # 0 = VAD sliding-window mode (best quality)
LENGTH="${WHISPER_LENGTH:-30000}"  # max audio window (ms) in VAD mode
VAD_THOLD="${WHISPER_VAD:-0.6}"    # voice-activity threshold
THREADS="${WHISPER_THREADS:-8}"
LANG="${WHISPER_LANG:-auto}"       # auto-detect; set e.g. "en" to pin

# --- preflight ---
if [[ ! -x "$BIN" ]]; then
  echo "error: whisper-stream not found at $BIN" >&2
  echo "build it: cd $WHISPER_DIR && cmake -B build -DWHISPER_COREML=1 -DWHISPER_SDL2=ON && cmake --build build -j --config Release" >&2
  exit 1
fi
if [[ ! -f "$MODEL" ]]; then
  echo "error: model not found at $MODEL" >&2
  echo "download: cd $WHISPER_DIR && sh ./models/download-ggml-model.sh large-v3-turbo" >&2
  exit 1
fi

echo "mic transcription | model=$(basename "$MODEL") | step=${STEP}ms length=${LENGTH}ms vad=${VAD_THOLD}"
echo "ctrl-c to stop. (needs Microphone permission for your terminal app)"
echo

# -fa = flash attention (faster on Metal). Extra args pass straight through.
exec "$BIN" \
  -m "$MODEL" \
  -t "$THREADS" \
  --step "$STEP" \
  --length "$LENGTH" \
  -vth "$VAD_THOLD" \
  -l "$LANG" \
  -fa \
  "$@"
