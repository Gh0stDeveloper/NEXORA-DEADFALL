import Link from "next/link";
import { formatBytes, formatDate, type ReleaseRecord } from "@/lib/releases";
import { ReleaseStatus } from "./ReleaseStatus";

export function ReleaseCard({ release }: { release: ReleaseRecord }) {
  return (
    <article className="history-card">
      <div className="history-card-top">
        <div>
          <p className="card-eyebrow">{release.channel.replace("_", " ")}</p>
          <h2>{release.version}</h2>
        </div>
        <ReleaseStatus status={release.status} />
      </div>
      <p className="history-summary">{release.summary}</p>
      <dl className="history-meta">
        <div>
          <dt>Publicación</dt>
          <dd>{formatDate(release.published_unix)}</dd>
        </div>
        <div>
          <dt>APK</dt>
          <dd>{release.download_available ? formatBytes(release.bytes) : "No disponible"}</dd>
        </div>
      </dl>
      <Link className="text-link" href={"/versiones/" + release.version}>
        Ver detalles de la versión
        <span aria-hidden="true">↗</span>
      </Link>
    </article>
  );
}
