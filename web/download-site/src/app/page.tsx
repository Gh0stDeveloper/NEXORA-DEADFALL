import Link from "next/link";
import { formatBytes, getCurrentRelease, getReleaseCatalog, type ReleaseRecord } from "@/lib/releases";
import { IntegrityBlock } from "./components/IntegrityBlock";
import { ReleaseFacts } from "./components/ReleaseFacts";
import { ReleaseSections } from "./components/ReleaseSections";
import { ReleaseStatus } from "./components/ReleaseStatus";

export const dynamic = "force-dynamic";

function downloadHref(download: string | null, available: boolean): string {
  return available && download ? download : "#";
}

export default async function Home() {
  const catalog = await getReleaseCatalog();
  const current = getCurrentRelease(catalog);
  const previous = catalog.releases.filter((release) => release.version !== current.version).slice(0, 2);
  const href = downloadHref(current.download, current.download_available);

  return (
    <main className="site-shell">
      <section className="home-hero">
        <div className="hero-copy">
          <p className="eyebrow">PORTAL OFICIAL / ANDROID / CLOSED BETA</p>
          <h1>Descarga <span>DEADFALL.</span></h1>
          <p className="hero-lead">
            La versión actual, sus cambios y los requisitos para entrar al brote desde un Android compatible.
          </p>
          <div className="hero-actions">
            <a className="button button-primary" href={href} aria-disabled={href === "#"}>
              Descargar APK actual
            </a>
            <Link className="button button-secondary" href="/versiones">
              Ver historial
            </Link>
          </div>
          <p className="hero-note">
            Verifica siempre el SHA-256 después de descargar. El enlace conserva la ruta oficial estable.
          </p>
        </div>
        <div className="hero-panel" aria-label="Estado de distribución">
          <div className="panel-grid-lines" aria-hidden="true" />
          <div className="panel-topline">
            <span>RELEASE CHANNEL</span>
            <span className="panel-live"><span className="status-dot" aria-hidden="true" /> LIVE</span>
          </div>
          <div className="panel-version">{current.version}</div>
          <div className="panel-caption">{current.summary}</div>
          <div className="panel-readout">
            <span>BUILD</span>
            <strong>{current.version_code}</strong>
            <span>PLAYERS</span>
            <strong>{current.max_players ? "1–" + current.max_players : "—"}</strong>
          </div>
        </div>
      </section>

      <section className="section-block" id="ultima-version">
        <div className="section-heading">
          <div>
            <p className="section-kicker">ÚLTIMA VERSIÓN</p>
            <h2>{current.version}</h2>
          </div>
          <ReleaseStatus status={current.status} />
        </div>
        <article className="release-feature">
          <div className="release-feature-copy">
            <p className="feature-label">{current.channel.replace("_", " ")} / BUILD {current.version_code}</p>
            <h3>{current.summary}</h3>
            <p>
              Descarga el APK actual, revisa sus cambios y conserva esta ficha para verificar futuras actualizaciones.
            </p>
          </div>
          <div className="release-feature-actions">
            <a className="button button-primary" href={href} aria-disabled={href === "#"}>
              Descargar APK
            </a>
            <Link className="text-link" href={"/versiones/" + current.version}>
              Abrir detalles de la versión
              <span aria-hidden="true">↗</span>
            </Link>
          </div>
        </article>
        <div className="release-data-grid">
          <ReleaseFacts release={current} />
          <IntegrityBlock release={current} />
        </div>
        <ReleaseSections release={current} />
      </section>

      <section className="section-block compact-section">
        <div className="section-heading">
          <div>
            <p className="section-kicker">HISTORIAL</p>
            <h2>Qué cambió antes</h2>
          </div>
          <Link className="text-link" href="/versiones">Ver todas <span aria-hidden="true">↗</span></Link>
        </div>
        <div className="history-grid">
          {previous.map((release) => <ReleaseCardProxy key={release.version} release={release} />)}
        </div>
      </section>

      <section className="portal-note">
        <div>
          <p className="section-kicker">COMPATIBILIDAD</p>
          <h2>Android ARM64 · API objetivo 36 · hasta 4 jugadores</h2>
        </div>
        <Link className="button button-secondary" href="/compatibilidad">Ver requisitos</Link>
      </section>
    </main>
  );
}

function ReleaseCardProxy({ release }: { release: ReleaseRecord }) {
  return (
    <article className="history-card history-card-mini">
      <div className="history-card-top">
        <div>
          <p className="card-eyebrow">{release.channel.replace("_", " ")}</p>
          <h3>{release.version}</h3>
        </div>
        <ReleaseStatus status={release.status} />
      </div>
      <p className="history-summary">{release.summary}</p>
      <p className="history-mini-meta">
        {formatBytes(release.bytes)} · {release.download_available ? "Descarga" : "Historial"}
      </p>
      <Link className="text-link" href={"/versiones/" + release.version}>
        Ver ficha <span aria-hidden="true">↗</span>
      </Link>
    </article>
  );
}
