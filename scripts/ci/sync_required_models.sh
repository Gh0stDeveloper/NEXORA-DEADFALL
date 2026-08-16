#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
VENDOR="$ROOT/vendor/Objetos3D"

vendor_ready(){
  [[ -s "$VENDOR/low poly survival character by Daren - WJiiE1qmRU.glb" ]] && \
  [[ -s "$VENDOR/Animated Character Base by J-Toastie - AZzoJo1FBm.glb" ]] && \
  [[ -s "$VENDOR/Animated Zombie by Quaternius - jkrEvQZb8J.glb" ]] && \
  [[ -s "$VENDOR/Zombie by cs_aaron - ftpTNkeqGWc.glb" ]]
}

if ! vendor_ready && [[ -z "${GH_TOKEN:-}" ]]; then
  echo "Objetos3D submodule is not initialized and DEADFALL_MODELS_TOKEN/GH_TOKEN is missing." >&2
  echo "CI must either checkout vendor/Objetos3D or provide read-only access to the private model repository." >&2
  exit 1
fi

bash "$ROOT/scripts/assets/sync_objetos3d.sh" "$ROOT"

required=(
  operator_01.glb
  operator_02.glb
  zombie_animated.glb
  zombie_static.glb
)
for model in "${required[@]}"; do
  path="$ROOT/assets/external/objetos3d/$model"
  if [[ ! -s "$path" ]]; then
    echo "Required Phase 11.3 runtime model missing after staging: $model" >&2
    exit 1
  fi
done

echo "[DEADFALL] Required vendored Objetos3D runtime assets staged for CI."
