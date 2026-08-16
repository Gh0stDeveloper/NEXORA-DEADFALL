#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SOURCE_REPO="${DEADFALL_MODELS_REPO:-Gh0stDeveloper/Objetos3D}"
DEST="$ROOT/assets/external/objetos3d"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$DEST"

clone_source(){
  if command -v gh >/dev/null 2>&1 && gh auth status --hostname github.com >/dev/null 2>&1; then
    gh repo clone "$SOURCE_REPO" "$TMP/source" -- --depth=1 --branch main >/dev/null
  else
    git clone --depth=1 --branch main "https://github.com/${SOURCE_REPO}.git" "$TMP/source" >/dev/null
  fi
}

copy_model(){
  local source_name="$1"
  local canonical_name="$2"
  local source_path="$TMP/source/$source_name"
  [[ -f "$source_path" ]] || {
    printf '[DEADFALL] Modelo no disponible todavía: %s\n' "$source_name" >&2
    return 0
  }
  install -m 0644 "$source_path" "$DEST/$canonical_name"
  printf '[DEADFALL] Modelo sincronizado: %s -> %s\n' "$source_name" "$canonical_name"
}

clone_source
copy_model "low poly survival character by Daren - WJiiE1qmRU.glb" "operator_01.glb"
copy_model "Animated Character Base by J-Toastie - AZzoJo1FBm.glb" "operator_02.glb"
copy_model "Animated Zombie by Quaternius - jkrEvQZb8J.glb" "zombie_animated.glb"
copy_model "Zombie by cs_aaron - ftpTNkeqGWc.glb" "zombie_static.glb"

# ZIP source packages are intentionally not copied. Only runtime GLB assets are staged.
# A future structure/building asset will be mapped here once it appears in Objetos3D.
printf '[DEADFALL] Objetos3D sync complete: %s\n' "$DEST"
