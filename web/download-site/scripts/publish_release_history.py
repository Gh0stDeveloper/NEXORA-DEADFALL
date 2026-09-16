#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import sys
import tempfile
from typing import Any

ALLOWED_STATUSES = {"current", "superseded", "withdrawn"}
REQUIRED_LISTS = ("added", "changed", "fixed", "networking", "android", "known_issues")
SHA256_RE = re.compile(r"^[0-9a-fA-F]{64}$")
GIT_SHA_RE = re.compile(r"^[0-9a-fA-F]{7,64}$")
STABLE_DOWNLOAD = "/downloads/NEXORA-DEADFALL-latest.apk"


def fail(message: str) -> None:
    raise SystemExit("DEADFALL_RELEASE_HISTORY_ERROR " + message)


def read_json(path: pathlib.Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None
    except json.JSONDecodeError as exc:
        fail(f"JSON inválido en {path}: {exc}")


def validate_optional(record: dict[str, Any], key: str, kind: type) -> None:
    value = record.get(key)
    if value is not None and (isinstance(value, bool) or not isinstance(value, kind)):
        fail(f"{record.get('version', '?')}: {key} tiene un tipo inválido")


def validate_catalog(catalog: Any) -> tuple[dict[str, Any], dict[str, Any]]:
    if not isinstance(catalog, dict):
        fail("el registro raíz debe ser un objeto")
    if catalog.get("schema_version") != 1:
        fail("schema_version debe ser 1")
    if not isinstance(catalog.get("current"), str) or not catalog["current"]:
        fail("current debe ser una versión no vacía")
    releases = catalog.get("releases")
    if not isinstance(releases, list) or not releases:
        fail("releases debe ser una lista no vacía")

    versions: set[str] = set()
    current_records: list[dict[str, Any]] = []
    for release in releases:
        if not isinstance(release, dict):
            fail("cada release debe ser un objeto")
        version = release.get("version")
        if not isinstance(version, str) or not version:
            fail("cada release necesita version")
        if version in versions:
            fail(f"versión duplicada: {version}")
        versions.add(version)
        version_code = release.get("version_code")
        if version_code is not None and (isinstance(version_code, bool) or not isinstance(version_code, int) or version_code < 1):
            fail(f"{version}: version_code inválido")
        if release.get("status") not in ALLOWED_STATUSES:
            fail(f"{version}: status inválido")
        if not isinstance(release.get("summary"), str) or not release["summary"]:
            fail(f"{version}: summary vacío")
        for key in REQUIRED_LISTS:
            if not isinstance(release.get(key), list) or not all(
                isinstance(item, str) and item.strip() for item in release[key]
            ):
                fail(f"{version}: {key} debe ser una lista de textos")
        for key in ("published_unix", "bytes", "min_client_version_code", "max_client_version_code",
                    "protocol", "content_version", "target_android_api", "max_players"):
            validate_optional(release, key, int)
        bytes_value = release.get("bytes")
        if bytes_value is not None and bytes_value < 1:
            fail(f"{version}: bytes debe ser positivo o null")
        sha = release.get("sha256")
        if sha is not None and (not isinstance(sha, str) or not SHA256_RE.fullmatch(sha)):
            fail(f"{version}: sha256 debe ser hexadecimal de 64 caracteres o null")
        git_sha = release.get("git_sha")
        if git_sha is not None and (not isinstance(git_sha, str) or not GIT_SHA_RE.fullmatch(git_sha)):
            fail(f"{version}: git_sha inválido")
        if not isinstance(release.get("download_available"), bool):
            fail(f"{version}: download_available debe ser boolean")
        if release.get("download") is not None and not isinstance(release["download"], str):
            fail(f"{version}: download debe ser texto o null")
        compatibility = release.get("compatibility")
        if not isinstance(compatibility, dict):
            fail(f"{version}: falta compatibility")
        for key in ("platform", "architecture", "network"):
            if not isinstance(compatibility.get(key), str) or not compatibility[key]:
                fail(f"{version}: compatibility.{key} inválido")
        if not isinstance(compatibility.get("server_authority"), bool):
            fail(f"{version}: compatibility.server_authority inválido")
        if release["status"] == "current":
            current_records.append(release)

    if catalog["current"] not in versions:
        fail("current no existe en releases")
    if len(current_records) != 1 or current_records[0]["version"] != catalog["current"]:
        fail("debe existir exactamente un release current y coincidir con current")
    return catalog, current_records[0]


def merge_runtime_manifest(catalog: dict[str, Any], current_record: dict[str, Any],
                           manifest: Any) -> dict[str, Any]:
    if manifest is None:
        return catalog
    if not isinstance(manifest, dict):
        fail("release.json debe ser un objeto")
    if manifest.get("version") != catalog["current"]:
        fail("release.json no coincide con la versión current del registro estructurado")
    if not isinstance(manifest.get("bytes"), int) or manifest["bytes"] < 1:
        fail("release.json.bytes debe ser positivo")
    sha = manifest.get("sha256")
    if not isinstance(sha, str) or not SHA256_RE.fullmatch(sha):
        fail("release.json.sha256 no es un SHA-256 válido")
    git_sha = manifest.get("git_sha")
    if not isinstance(git_sha, str) or not GIT_SHA_RE.fullmatch(git_sha):
        fail("release.json.git_sha no es un commit válido")
    published = manifest.get("published_unix")
    if not isinstance(published, int) or published < 1:
        fail("release.json.published_unix debe ser positivo")
    if manifest.get("download") != STABLE_DOWNLOAD:
        fail("release.json.download debe conservar la ruta APK estable")
    current_record.update({
        "published_unix": published,
        "bytes": manifest["bytes"],
        "sha256": sha.lower(),
        "git_sha": git_sha.lower(),
        "download": STABLE_DOWNLOAD,
        "download_available": True,
    })
    return catalog


def write_atomic(path: pathlib.Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".releases.", suffix=".json", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(data, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
        os.chmod(temporary, 0o644)
        os.replace(temporary, path)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def main() -> None:
    parser = argparse.ArgumentParser(description="Publica el historial durable de releases de DEADFALL.")
    parser.add_argument("--source", required=True, type=pathlib.Path)
    parser.add_argument("--current", type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    args = parser.parse_args()

    source = read_json(args.source)
    catalog, current_record = validate_catalog(source)
    manifest = read_json(args.current) if args.current else None
    merge_runtime_manifest(catalog, current_record, manifest)
    validate_catalog(catalog)
    write_atomic(args.output, catalog)
    print(
        "DEADFALL_RELEASE_HISTORY_PUBLISHED "
        f"output={args.output} current={catalog['current']} releases={len(catalog['releases'])} "
        f"runtime_manifest={'yes' if manifest is not None else 'no'}"
    )


if __name__ == "__main__":
    main()
