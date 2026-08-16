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

validate_glb(){
  local path="$1"
  python3 - "$path" <<'PY'
import pathlib
import struct
import sys

path = pathlib.Path(sys.argv[1])
data = path.read_bytes()
if len(data) < 12:
    raise SystemExit(f"GLB too small: {path}")
magic, version, declared_length = struct.unpack("<4sII", data[:12])
if magic != b"glTF":
    raise SystemExit(f"Invalid GLB magic: {path}")
if version != 2:
    raise SystemExit(f"Unsupported GLB version {version}: {path}")
if declared_length != len(data):
    raise SystemExit(
        f"GLB length mismatch for {path}: header={declared_length} actual={len(data)}"
    )
PY
}

copy_model(){
  local source_name="$1"
  local canonical_name="$2"
  local source_path="$TMP/source/$source_name"
  local destination_path="$DEST/$canonical_name"

  # Never keep an ignored/staged binary from an older deployment when its
  # authoritative source disappeared. The runtime fallback is safer than
  # silently shipping a stale model on only some VPS installations.
  rm -f "$destination_path"

  [[ -f "$source_path" ]] || {
    printf '[DEADFALL] Modelo no disponible; se usará fallback: %s\n' "$source_name" >&2
    return 0
  }

  validate_glb "$source_path"
  install -m 0644 "$source_path" "$destination_path"
  validate_glb "$destination_path"
  printf '[DEADFALL] Modelo sincronizado y validado: %s -> %s\n' "$source_name" "$canonical_name"
}

clone_source
copy_model "low poly survival character by Daren - WJiiE1qmRU.glb" "operator_01.glb"
copy_model "Animated Character Base by J-Toastie - AZzoJo1FBm.glb" "operator_02.glb"
copy_model "Animated Zombie by Quaternius - jkrEvQZb8J.glb" "zombie_animated.glb"
copy_model "Zombie by cs_aaron - ftpTNkeqGWc.glb" "zombie_static.glb"

# ZIP source packages are intentionally not copied. Only runtime GLB assets are staged.
# A future structure/building asset will be mapped here once it appears in Objetos3D.
printf '[DEADFALL] Objetos3D sync complete: %s\n' "$DEST"
