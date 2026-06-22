#!/usr/bin/env bash
# One-shot installer for the whisper-mic engine on a fresh Apple Silicon Mac.
# Idempotent: re-running skips work already done.
#
# Installs: SDL2 + cmake (brew), clones & builds whisper.cpp (Metal + Core ML
# + SDL2), downloads the model, and generates the Core ML encoder.
# Core ML is best-effort — if its Python toolchain fails, you still get a
# fully working Metal mic.
set -euo pipefail

WHISPER_DIR="${WHISPER_DIR:-$HOME/whisper.cpp}"
MODEL_NAME="${WHISPER_MODEL_NAME:-large-v3-turbo}"
MODEL_BIN="$WHISPER_DIR/models/ggml-${MODEL_NAME}.bin"
MLMODELC="$WHISPER_DIR/models/ggml-${MODEL_NAME}-encoder.mlmodelc"
VENV="$WHISPER_DIR/.coreml-venv"

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mwarning: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31merror: %s\033[0m\n' "$*" >&2; exit 1; }

# --- 1. preflight ---------------------------------------------------------
[[ "$(uname -s)" == "Darwin" ]] || die "macOS only."
[[ "$(uname -m)" == "arm64" ]] || die "Apple Silicon (arm64) required; this Mac is $(uname -m)."
command -v brew >/dev/null || die "Homebrew not found. Install from https://brew.sh first."

# --- 2. brew deps ---------------------------------------------------------
say "Installing build deps (sdl2, cmake)"
brew install sdl2 cmake
# cmake/brew bins may not be on PATH in non-login shells; resolve explicitly.
CMAKE="$(command -v cmake || echo "$(brew --prefix)/bin/cmake")"
[[ -x "$CMAKE" ]] || die "cmake still not found after install."

# --- 3. clone / update ----------------------------------------------------
if [[ -d "$WHISPER_DIR/.git" ]]; then
  say "whisper.cpp present — pulling latest"
  git -C "$WHISPER_DIR" pull --ff-only || warn "git pull failed; using existing checkout."
else
  say "Cloning whisper.cpp -> $WHISPER_DIR"
  git clone https://github.com/ggml-org/whisper.cpp "$WHISPER_DIR"
fi

# --- 4. build (Metal default + Core ML + SDL2) ----------------------------
say "Building (Metal + Core ML + SDL2)"
"$CMAKE" -B "$WHISPER_DIR/build" -S "$WHISPER_DIR" -DWHISPER_COREML=1 -DWHISPER_SDL2=ON
"$CMAKE" --build "$WHISPER_DIR/build" -j --config Release
[[ -x "$WHISPER_DIR/build/bin/whisper-stream" ]] || die "whisper-stream did not build."

# --- 5. model -------------------------------------------------------------
if [[ -f "$MODEL_BIN" ]]; then
  say "Model already present: $(basename "$MODEL_BIN")"
else
  say "Downloading model: $MODEL_NAME"
  ( cd "$WHISPER_DIR" && sh ./models/download-ggml-model.sh "$MODEL_NAME" )
fi

# --- 6. Core ML encoder (best-effort) -------------------------------------
if [[ -d "$MLMODELC" ]]; then
  say "Core ML encoder already present — skipping conversion"
else
  say "Generating Core ML encoder (best-effort)"
  # Locate a Python 3.11 interpreter (coremltools is picky about version).
  PY311=""
  if command -v python3.11 >/dev/null; then
    PY311="$(command -v python3.11)"
  elif command -v pyenv >/dev/null; then
    pyenv install -s 3.11 || true
    PY311="$(pyenv root)/versions/$(pyenv versions --bare | grep -E '^3\.11' | tail -1)/bin/python" || true
  elif brew install python@3.11 2>/dev/null; then
    PY311="$(brew --prefix)/opt/python@3.11/bin/python3.11"
  fi

  if [[ -z "$PY311" || ! -x "$PY311" ]]; then
    warn "No Python 3.11 found — skipping Core ML. Metal-only mic still works."
  else
    if "$PY311" -m venv "$VENV" \
       && "$VENV/bin/pip" install -q --upgrade pip \
       && "$VENV/bin/pip" install -q ane_transformers openai-whisper coremltools \
       && ( cd "$WHISPER_DIR" && PATH="$VENV/bin:$PATH" ./models/generate-coreml-model.sh "$MODEL_NAME" ) \
       && [[ -d "$MLMODELC" ]]; then
      say "Core ML encoder generated"
    else
      warn "Core ML conversion failed — Metal-only mic still works. Re-run setup.sh to retry."
    fi
  fi
fi

# --- 7. done --------------------------------------------------------------
say "Setup complete"
echo "Engine:  $WHISPER_DIR"
echo "Model:   $MODEL_BIN"
echo "Core ML: $([[ -d "$MLMODELC" ]] && echo "yes" || echo "no (Metal only)")"
echo
echo "Run:     $(cd "$(dirname "$0")" && pwd)/mic.sh"
echo "First:   grant Microphone permission to your terminal app (see README)."
