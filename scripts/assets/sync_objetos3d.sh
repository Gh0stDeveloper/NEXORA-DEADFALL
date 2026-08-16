#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SOURCE_REPO="${DEADFALL_MODELS_REPO:-Gh0stDeveloper/Objetos3D}"
VENDOR="$ROOT/vendor/Objetos3D"
DEST="$ROOT/assets/external/objetos3d"
TMP="$(mktemp -d)"
SOURCE_DIR=""
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$DEST"

has_required_source_models(){
  local dir="$1"
  [[ -s "$dir/low poly survival character by Daren - WJiiE1qmRU.glb" ]] && \
  [[ -s "$dir/Animated Character Base by J-Toastie - AZzoJo1FBm.glb" ]] && \
  [[ -s "$dir/Animated Zombie by Quaternius - jkrEvQZb8J.glb" ]] && \
  [[ -s "$dir/Zombie by cs_aaron - ftpTNkeqGWc.glb" ]]
}

prepare_source(){
  # Preferred path: Objetos3D is now versioned by DEADFALL as a pinned Git
  # submodule. On the production VPS the deadfall service account already has
  # GitHub authentication, so normal update/install flows can initialize it.
  if has_required_source_models "$VENDOR"; then
    SOURCE_DIR="$VENDOR"
    printf '[DEADFALL] Using vendored Objetos3D submodule: %s\n' "$VENDOR"
    return 0
  fi

  if [[ -f "$ROOT/.gitmodules" ]] && git -C "$ROOT" config -f .gitmodules --get-regexp '^submodule\.vendor/Objetos3D\.path$' >/dev/null 2>&1; then
    printf '[DEADFALL] Initializing vendored Objetos3D submodule...\n'
    git -C "$ROOT" submodule sync -- vendor/Objetos3D >/dev/null 2>&1 || true
    if git -C "$ROOT" submodule update --init --recursive --depth 1 vendor/Objetos3D >/dev/null 2>&1 && has_required_source_models "$VENDOR"; then
      SOURCE_DIR="$VENDOR"
      printf '[DEADFALL] Vendored Objetos3D submodule ready.\n'
      return 0
    fi
    printf '[DEADFALL] Vendored submodule could not be initialized; trying authenticated clone fallback.\n' >&2
  fi

  if command -v gh >/dev/null 2>&1 && gh auth status --hostname github.com >/dev/null 2>&1; then
    gh repo clone "$SOURCE_REPO" "$TMP/source" -- --depth=1 --branch main >/dev/null
  else
    git clone --depth=1 --branch main "https://github.com/${SOURCE_REPO}.git" "$TMP/source" >/dev/null
  fi
  has_required_source_models "$TMP/source" || {
    printf '[DEADFALL] Objetos3D source is incomplete; all four Phase 11.3 GLBs are required.\n' >&2
    exit 1
  }
  SOURCE_DIR="$TMP/source"
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
  local source_path="$SOURCE_DIR/$source_name"
  local destination_path="$DEST/$canonical_name"

  rm -f "$destination_path"
  [[ -f "$source_path" ]] || {
    printf '[DEADFALL] Required model missing from vendored source: %s\n' "$source_name" >&2
    exit 1
  }

  validate_glb "$source_path"
  install -m 0644 "$source_path" "$destination_path"
  validate_glb "$destination_path"
  printf '[DEADFALL] Modelo staged and validated: %s -> %s\n' "$source_name" "$canonical_name"
}

prepare_source
copy_model "low poly survival character by Daren - WJiiE1qmRU.glb" "operator_01.glb"
copy_model "Animated Character Base by J-Toastie - AZzoJo1FBm.glb" "operator_02.glb"
copy_model "Animated Zombie by Quaternius - jkrEvQZb8J.glb" "zombie_animated.glb"
copy_model "Zombie by cs_aaron - ftpTNkeqGWc.glb" "zombie_static.glb"

# ZIP source packages are intentionally not staged into the Godot runtime path.
# A future structure/building asset will receive a stable canonical mapping here.
printf '[DEADFALL] Objetos3D staging complete: source=%s destination=%s\n' "$SOURCE_DIR" "$DEST"
