import {
  formatBytes,
  formatDate,
  shortSha,
  type ReleaseRecord,
} from "@/lib/releases";

export function ReleaseFacts({ release }: { release: ReleaseRecord }) {
  const facts: Array<[string, string]> = [
    ["Publicación", formatDate(release.published_unix)],
    ["Versión code", release.version_code ? String(release.version_code) : "No disponible"],
    ["Tamaño APK", formatBytes(release.bytes)],
    ["Android", release.target_android_api ? "API " + release.target_android_api : "No disponible"],
    ["Protocolo", release.protocol ? String(release.protocol) : "No disponible"],
    ["Squad", release.max_players ? "Hasta " + release.max_players + " jugadores" : "No disponible"],
    ["Commit", shortSha(release.git_sha)],
  ];

  return (
    <dl className="release-facts">
      {facts.map(([label, value]) => (
        <div className="fact" key={label}>
          <dt>{label}</dt>
          <dd>{value}</dd>
        </div>
      ))}
    </dl>
  );
}
