#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATENTSYNC_DIR="${LATENTSYNC_DIR:-"$ROOT_DIR/external/LatentSync"}"
ENV_NAME="${ENV_NAME:-latentsync}"

DEFAULT_VIDEO="$ROOT_DIR/work/prepared/kobori_video_clean.mp4"
DEFAULT_AUDIO="$ROOT_DIR/materiais_teste/kobori_audio_separado.wav"
DEBUG_AUDIO="$ROOT_DIR/work/prepared/kobori_audio_16k_mono.wav"

if [[ ! -f "$DEFAULT_VIDEO" || ! -f "$DEBUG_AUDIO" ]]; then
  bash "$ROOT_DIR/scripts/preflight_media.sh"
fi

VIDEO_PATH="${VIDEO_PATH:-"$DEFAULT_VIDEO"}"
if [[ "${USE_16K_AUDIO:-0}" == "1" ]]; then
  AUDIO_PATH="${AUDIO_PATH:-"$DEBUG_AUDIO"}"
else
  AUDIO_PATH="${AUDIO_PATH:-"$DEFAULT_AUDIO"}"
fi

OUT_PATH="${OUT_PATH:-"$ROOT_DIR/outputs/kobori_latentsync_1_6.mp4"}"
TEMP_DIR="${TEMP_DIR:-"$ROOT_DIR/work/latentsync_temp"}"
STEPS="${STEPS:-20}"
GUIDANCE="${GUIDANCE:-1.5}"
SEED="${SEED:-1247}"
ENABLE_DEEPCACHE="${ENABLE_DEEPCACHE:-1}"

if [[ ! -d "$LATENTSYNC_DIR" ]]; then
  echo "LatentSync directory not found: $LATENTSYNC_DIR" >&2
  echo "Run: bash scripts/setup_latentsync_1_6.sh" >&2
  exit 1
fi

if ! command -v conda >/dev/null 2>&1; then
  echo "conda was not found. Activate/install conda, then rerun." >&2
  exit 1
fi

export_python_nvidia_libs() {
  local site_packages
  site_packages="$(python - <<'PY'
import site
paths = site.getsitepackages()
print(paths[0])
PY
)"

  local lib_dirs=("$CONDA_PREFIX/lib")
  local nvidia_lib
  for nvidia_lib in "$site_packages"/nvidia/*/lib; do
    if [[ -d "$nvidia_lib" ]]; then
      lib_dirs+=("$nvidia_lib")
    fi
  done

  local joined
  joined="$(IFS=:; echo "${lib_dirs[*]}")"
  export LD_LIBRARY_PATH="$joined${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
}

mkdir -p "$(dirname "$OUT_PATH")" "$TEMP_DIR"

CONDA_BASE="$(conda info --base)"
source "$CONDA_BASE/etc/profile.d/conda.sh"
conda activate "$ENV_NAME"
export_python_nvidia_libs

if ! python - <<'PY'
import torch
if not torch.cuda.is_available():
    raise SystemExit("CUDA is not available to PyTorch")
print("CUDA device:", torch.cuda.get_device_name(0))
props = torch.cuda.get_device_properties(0)
print("VRAM GB:", round(props.total_memory / 1024**3, 2))
PY
then
  echo "PyTorch/CUDA check failed. Confirm NVIDIA driver, CUDA wheel, and GPU availability." >&2
  exit 1
fi

cd "$LATENTSYNC_DIR"

DEEPCACHE_FLAG=()
if [[ "$ENABLE_DEEPCACHE" == "1" ]]; then
  DEEPCACHE_FLAG=(--enable_deepcache)
fi

python -m scripts.inference \
  --unet_config_path "configs/unet/stage2_512.yaml" \
  --inference_ckpt_path "checkpoints/latentsync_unet.pt" \
  --inference_steps "$STEPS" \
  --guidance_scale "$GUIDANCE" \
  "${DEEPCACHE_FLAG[@]}" \
  --video_path "$VIDEO_PATH" \
  --audio_path "$AUDIO_PATH" \
  --video_out_path "$OUT_PATH" \
  --temp_dir "$TEMP_DIR" \
  --seed "$SEED"

echo
echo "Output video: $OUT_PATH"
