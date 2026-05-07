#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_NAME="${ENV_NAME:-latentsync}"

VIDEO_SOURCE="${VIDEO_PATH:-"$ROOT_DIR/materiais_teste/kobori_sem_audio.mp4"}"
AUDIO_SOURCE="${AUDIO_PATH:-"$ROOT_DIR/materiais_teste/kobori_audio_separado.wav"}"
WORK_DIR="$ROOT_DIR/work/prepared"

mkdir -p "$WORK_DIR"

activate_conda_env_if_needed() {
  if command -v ffmpeg >/dev/null 2>&1 && command -v ffprobe >/dev/null 2>&1; then
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

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "Missing file: $1" >&2
    exit 1
  fi
}

duration_of() {
  ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$1"
}

activate_conda_env_if_needed
require_cmd ffmpeg
require_cmd ffprobe
require_file "$VIDEO_SOURCE"
require_file "$AUDIO_SOURCE"

VIDEO_DURATION="$(duration_of "$VIDEO_SOURCE")"
AUDIO_DURATION="$(duration_of "$AUDIO_SOURCE")"
DIFF_SECONDS="$(awk -v v="$VIDEO_DURATION" -v a="$AUDIO_DURATION" 'BEGIN { d=a-v; if (d<0) d=-d; printf "%.3f", d }')"

echo "Video: $VIDEO_SOURCE"
ffprobe -v error -select_streams v:0 \
  -show_entries stream=codec_name,width,height,avg_frame_rate,duration \
  -of default=nk=1:nw=1 "$VIDEO_SOURCE"

echo
echo "Audio: $AUDIO_SOURCE"
ffprobe -v error -select_streams a:0 \
  -show_entries stream=codec_name,sample_rate,channels,bits_per_sample,duration \
  -of default=nk=1:nw=1 "$AUDIO_SOURCE"

echo
echo "Duration delta: ${DIFF_SECONDS}s"

CLEAN_VIDEO="$WORK_DIR/kobori_video_clean.mp4"
AUDIO_16K="$WORK_DIR/kobori_audio_16k_mono.wav"

ffmpeg -hide_banner -y -i "$VIDEO_SOURCE" -map 0:v:0 -c:v copy -an -dn "$CLEAN_VIDEO"
ffmpeg -hide_banner -y -i "$AUDIO_SOURCE" -ac 1 -ar 16000 -sample_fmt s16 "$AUDIO_16K"

echo
echo "Prepared video: $CLEAN_VIDEO"
echo "Prepared 16 kHz debug audio: $AUDIO_16K"
