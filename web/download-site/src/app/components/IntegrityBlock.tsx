import { formatBytes, formatSha256, type ReleaseRecord } from "@/lib/releases";

export function IntegrityBlock({ release }: { release: ReleaseRecord }) {
  return (
    <div className="integrity-block">
      <div className="integrity-heading">
        <div>
          <p className="section-kicker">VERIFICACIÓN</p>
          <h3>Integridad del archivo</h3>
        </div>
        <span className="integrity-mark" aria-hidden="true">
          ✓
        </span>
      </div>
      <div className="integrity-row">
        <span>Tamaño</span>
        <strong>{formatBytes(release.bytes)}</strong>
      </div>
      <div className="integrity-row integrity-hash">
        <span>SHA-256</span>
        <code>{formatSha256(release.sha256)}</code>
      </div>
      <p className="integrity-note">
        El hash se muestra para comparar el APK descargado con el archivo publicado.
      </p>
    </div>
  );
}
