#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATENTSYNC_DIR="${LATENTSYNC_DIR:-"$ROOT_DIR/external/LatentSync"}"
ENV_NAME="${ENV_NAME:-latentsync}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

install_apt_packages() {
  if ! command -v apt-get >/dev/null 2>&1; then
    return 1
  fi

  local apt_cmd=(apt-get)
  if [[ "$(id -u)" != "0" ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
      return 1
    fi
    apt_cmd=(sudo apt-get)
  fi

  "${apt_cmd[@]}" update
  "${apt_cmd[@]}" install -y \
    build-essential \
    ffmpeg \
    gcc \
    g++ \
    libgl1 \
    libglib2.0-0
}

require_cmd git

if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi
else
  echo "Warning: nvidia-smi not found. LatentSync 1.6 needs a CUDA/NVIDIA GPU for this setup." >&2
fi

if ! command -v conda >/dev/null 2>&1; then
  echo "conda was not found. Install Miniconda/Mambaforge first, then rerun this script." >&2
  echo "Example: https://docs.conda.io/projects/miniconda/en/latest/" >&2
  exit 1
fi

if [[ ! -d "$LATENTSYNC_DIR/.git" ]]; then
  mkdir -p "$(dirname "$LATENTSYNC_DIR")"
  git clone https://github.com/bytedance/LatentSync.git "$LATENTSYNC_DIR"
fi

CONDA_BASE="$(conda info --base)"
source "$CONDA_BASE/etc/profile.d/conda.sh"

if ! conda env list | awk '{print $1}' | grep -qx "$ENV_NAME"; then
  conda create -y -n "$ENV_NAME" python=3.10.13
fi

conda activate "$ENV_NAME"

conda install -y -c conda-forge ffmpeg

if install_apt_packages; then
  echo "System build/OpenCV dependencies installed with apt-get."
else
  echo "apt-get was not available. Installing compiler toolchain through conda instead."
  conda install -y -c conda-forge cxx-compiler compilers
fi

cd "$LATENTSYNC_DIR"
pip install -r requirements.txt
pip install hf_xet nvidia-cuda-nvrtc-cu12

huggingface-cli download ByteDance/LatentSync-1.6 whisper/tiny.pt --local-dir checkpoints
huggingface-cli download ByteDance/LatentSync-1.6 latentsync_unet.pt --local-dir checkpoints

echo
echo "LatentSync 1.6 is ready at: $LATENTSYNC_DIR"
echo "Conda env: $ENV_NAME"
