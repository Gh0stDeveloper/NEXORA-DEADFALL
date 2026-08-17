#!/usr/bin/env python3
"""NEXORA: DEADFALL Android Gradle template sanitizer.

The Godot Android template is generated under android/build and is intentionally
not versioned. This helper applies only DEADFALL-owned, idempotent compatibility
patches to that generated tree.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys

TARGET_ANDROID_NAMES = {
    "android.hardware.vulkan.level",
    "android.hardware.vulkan.version",
    "org.godotengine.rendering.method",
    "org.godotengine.editor.version",
}


def _set_gradle_property(path: Path, key: str, value: str) -> bool:
    if not path.exists():
        raise FileNotFoundError(f"Gradle properties file not found: {path}")
    original = path.read_text(encoding="utf-8")
    pattern = re.compile(rf"(?m)^\s*{re.escape(key)}\s*=.*$")
    replacement = f"{key}={value}"
    if pattern.search(original):
        updated = pattern.sub(replacement, original, count=1)
    else:
        updated = original
        if updated and not updated.endswith("\n"):
            updated += "\n"
        updated += replacement + "\n"
    if updated != original:
        path.write_text(updated, encoding="utf-8")
        return True
    return False


def _remove_tools_replace_from_target_tag(tag_text: str) -> tuple[str, bool]:
    name_match = re.search(
        r"\bandroid:name\s*=\s*([\"'])(?P<name>[^\"']+)\1", tag_text
    )
    if name_match is None or name_match.group("name") not in TARGET_ANDROID_NAMES:
        return tag_text, False
    updated, count = re.subn(
        r"\s+tools:replace\s*=\s*([\"'])[^\"']*\1", "", tag_text, count=1
    )
    return updated, count > 0


def sanitize_manifest(path: Path, *, required: bool) -> int:
    if not path.exists():
        if required:
            raise FileNotFoundError(f"Release manifest not found: {path}")
        return 0
    original = path.read_text(encoding="utf-8")
    changed = 0

    def replace_tag(match: re.Match[str]) -> str:
        nonlocal changed
        updated, did_change = _remove_tools_replace_from_target_tag(match.group(0))
        if did_change:
            changed += 1
        return updated

    # Only inspect the two element types that produced Android Manifest Merger
    # warnings. Never change activities, services, permissions or application
    # attributes.
    updated = re.sub(r"<(?:uses-feature|meta-data)\b[^>]*?/?>", replace_tag, original)
    if updated != original:
        path.write_text(updated, encoding="utf-8")
    return changed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("android_build_dir", type=Path)
    parser.add_argument("--manifest-only", action="store_true")
    parser.add_argument("--require-manifest", action="store_true")
    args = parser.parse_args()

    build_dir = args.android_build_dir.resolve()
    if not build_dir.is_dir():
        raise FileNotFoundError(f"Android build template directory not found: {build_dir}")

    if not args.manifest_only:
        gradle_properties = build_dir / "gradle.properties"
        changed = _set_gradle_property(
            gradle_properties, "android.suppressUnsupportedCompileSdk", "36"
        )
        print(
            "DEADFALL_ANDROID_GRADLE_PROPERTIES "
            f"path={gradle_properties} compile_sdk_warning_suppressed=36 changed={str(changed).lower()}"
        )

    manifest = build_dir / "src" / "release" / "AndroidManifest.xml"
    removed = sanitize_manifest(manifest, required=args.require_manifest)
    print(
        "DEADFALL_ANDROID_MANIFEST_SANITIZED "
        f"path={manifest} redundant_tools_replace_removed={removed}"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # deterministic failure for VPS/CI callers
        print(f"DEADFALL_ANDROID_TEMPLATE_PATCH_FAILED {exc}", file=sys.stderr)
        raise SystemExit(1)
