import Link from "next/link";
import { getCurrentRelease, getReleaseCatalog } from "@/lib/releases";
import { ReleaseStatus } from "../components/ReleaseStatus";

export const dynamic = "force-dynamic";

export default async function CompatibilityPage() {
  const current = getCurrentRelease(await getReleaseCatalog());

  return (
    <main className="site-shell page-shell">
      <section className="page-intro">
        <p className="eyebrow">ANDROID / CLOSED BETA / REQUISITOS</p>
        <h1>Compatibilidad clara.</h1>
        <p>Estos son los datos públicos de la versión vigente y las condiciones mínimas declaradas para probarla.</p>
      </section>

      <section className="compatibility-hero">
        <div className="compatibility-status">
          <ReleaseStatus status={current.status} />
          <span>{current.version}</span>
        </div>
        <h2>Android ARM64 para escuadras de hasta {current.max_players ?? 4} jugadores.</h2>
        <p>
          El cliente y el servidor deben respetar el mismo contrato de versión, protocolo y contenido para entrar a una partida.
        </p>
      </section>

      <section className="compatibility-grid">
        <article className="compatibility-card">
          <p className="section-kicker">DISPOSITIVO</p>
          <h2>Android ARM64</h2>
          <dl><div><dt>API objetivo</dt><dd>{current.target_android_api ?? "No disponible"}</dd></div><div><dt>Canal</dt><dd>{current.channel}</dd></div></dl>
        </article>
        <article className="compatibility-card">
          <p className="section-kicker">RED</p>
          <h2>Online autoritativo</h2>
          <dl><div><dt>Protocolo</dt><dd>{current.protocol ?? "No disponible"}</dd></div><div><dt>Contenido</dt><dd>{current.content_version ?? "No disponible"}</dd></div></dl>
        </article>
        <article className="compatibility-card">
          <p className="section-kicker">SQUAD</p>
          <h2>1–{current.max_players ?? 4} jugadores</h2>
          <dl><div><dt>Cliente mínimo</dt><dd>{current.min_client_version_code ?? "No disponible"}</dd></div><div><dt>Cliente máximo</dt><dd>{current.max_client_version_code ?? "No disponible"}</dd></div></dl>
        </article>
      </section>

      <div className="info-callout">
        <strong>Estado de validación.</strong>
        <span>La publicación automatizada está completa; la aceptación física de Solo, Duo, reconexión, 3 y 4 jugadores se registra por separado.</span>
      </div>
      <Link className="button button-secondary inline-button" href={"/versiones/" + current.version}>Ver ficha completa</Link>
    </main>
  );
}
