#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "Missing DEADFALL_MODELS_TOKEN/GH_TOKEN. CI builds must stage the private Objetos3D runtime assets." >&2
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
    echo "Required Phase 11.3 runtime model missing after sync: $model" >&2
    exit 1
  fi
done

echo "[DEADFALL] Required Objetos3D runtime assets staged for CI."
