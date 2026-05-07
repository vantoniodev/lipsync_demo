#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_NAME="${ENV_NAME:-latentsync}"
SECONDS_TO_CUT="${1:-15}"

VIDEO_SOURCE="${VIDEO_PATH:-"$ROOT_DIR/materiais_teste/kobori_sem_audio.mp4"}"
AUDIO_SOURCE="${AUDIO_PATH:-"$ROOT_DIR/materiais_teste/kobori_audio_separado.wav"}"
SMOKE_DIR="$ROOT_DIR/work/smoke"

mkdir -p "$SMOKE_DIR"

activate_conda_env_if_needed() {
  if command -v ffmpeg >/dev/null 2>&1; then
    return 0
  fi

  if ! command -v conda >/dev/null 2>&1; then
    return 0
  fi

  local conda_base
  conda_base="$(conda info --base)"
  # shellcheck disable=SC1091
  source "$conda_base/etc/profile.d/conda.sh"
  conda activate "$ENV_NAME"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

activate_conda_env_if_needed
require_cmd ffmpeg

VIDEO_OUT="$SMOKE_DIR/kobori_video_${SECONDS_TO_CUT}s.mp4"
AUDIO_OUT="$SMOKE_DIR/kobori_audio_${SECONDS_TO_CUT}s.wav"

ffmpeg -hide_banner -y -t "$SECONDS_TO_CUT" -i "$VIDEO_SOURCE" -map 0:v:0 -c:v copy -an -dn "$VIDEO_OUT"
ffmpeg -hide_banner -y -t "$SECONDS_TO_CUT" -i "$AUDIO_SOURCE" -c:a pcm_s16le "$AUDIO_OUT"

echo "Smoke video: $VIDEO_OUT"
echo "Smoke audio: $AUDIO_OUT"
