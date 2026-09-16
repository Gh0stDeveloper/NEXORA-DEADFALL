import fs from "node:fs/promises";
import seedCatalog from "@/data/releases.json";

export type ReleaseStatus = "current" | "superseded" | "withdrawn";

export type Compatibility = {
  platform: string;
  architecture: string;
  network: string;
  server_authority: boolean;
};

export type ReleaseRecord = {
  version: string;
  version_code: number | null;
  channel: string;
  published_unix: number | null;
  status: ReleaseStatus;
  summary: string;
  added: string[];
  changed: string[];
  fixed: string[];
  networking: string[];
  android: string[];
  known_issues: string[];
  min_client_version_code: number | null;
  max_client_version_code: number | null;
  protocol: number | null;
  content_version: number | null;
  target_android_api: number | null;
  max_players: number | null;
  bytes: number | null;
  sha256: string | null;
  git_sha: string | null;
  download: string | null;
  download_available: boolean;
  compatibility: Compatibility;
};

export type ReleaseCatalog = {
  schema_version: number;
  current: string;
  releases: ReleaseRecord[];
};

const seed = seedCatalog as ReleaseCatalog;
const historyPath =
  process.env.DEADFALL_RELEASE_HISTORY ?? "/var/www/nexora-deadfall/releases.json";

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function isCatalog(value: unknown): value is ReleaseCatalog {
  if (!isRecord(value)) return false;
  if (value.schema_version !== 1 || typeof value.current !== "string") return false;
  if (!Array.isArray(value.releases) || value.releases.length === 0) return false;
  return value.releases.every((release) => {
    if (!isRecord(release)) return false;
    return (
      typeof release.version === "string" &&
      (release.version_code === null || typeof release.version_code === "number") &&
      typeof release.status === "string" &&
      ["current", "superseded", "withdrawn"].includes(release.status) &&
      typeof release.summary === "string" &&
      Array.isArray(release.added) &&
      Array.isArray(release.changed) &&
      Array.isArray(release.fixed) &&
      Array.isArray(release.networking) &&
      Array.isArray(release.android) &&
      Array.isArray(release.known_issues)
    );
  });
}

async function readRuntimeCatalog(): Promise<ReleaseCatalog | null> {
  try {
    // Managed runtime data lives outside the standalone app and changes after
    // APK publication. Do not trace the whole source tree for this dynamic path.
    const raw = await fs.readFile(/* turbopackIgnore: true */ historyPath, "utf8");
    const parsed: unknown = JSON.parse(raw);
    return isCatalog(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

export async function getReleaseCatalog(): Promise<ReleaseCatalog> {
  return (await readRuntimeCatalog()) ?? seed;
}

export function getCurrentRelease(catalog: ReleaseCatalog): ReleaseRecord {
  return (
    catalog.releases.find((release) => release.version === catalog.current) ??
    catalog.releases[0]
  );
}

export function findRelease(
  catalog: ReleaseCatalog,
  version: string,
): ReleaseRecord | null {
  return catalog.releases.find((release) => release.version === version) ?? null;
}

export function formatBytes(bytes: number | null): string {
  if (!bytes || bytes < 1) return "No disponible";
  return String((bytes / 1024 / 1024).toFixed(1)) + " MB";
}

export function formatDate(unix: number | null): string {
  if (!unix || unix < 1) return "Pendiente de registro";
  return new Intl.DateTimeFormat("es-MX", {
    dateStyle: "medium",
    timeZone: "UTC",
  }).format(new Date(unix * 1000));
}

export function formatSha256(sha256: string | null): string {
  return sha256 && sha256.length > 0 ? sha256 : "Se calculará al publicar el APK";
}

export function shortSha(sha: string | null): string {
  return sha && sha.length >= 8 ? sha.slice(0, 8) : "No disponible";
}

export function statusLabel(status: ReleaseStatus): string {
  switch (status) {
    case "current":
      return "Current";
    case "withdrawn":
      return "Withdrawn";
    default:
      return "Superseded";
  }
}

export function statusClass(status: ReleaseStatus): string {
  return "status-" + status;
}
