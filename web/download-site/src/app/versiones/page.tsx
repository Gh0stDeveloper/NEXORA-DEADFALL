import { getReleaseCatalog } from "@/lib/releases";
import { ReleaseCard } from "../components/ReleaseCard";

export const dynamic = "force-dynamic";

export default async function VersionsPage() {
  const catalog = await getReleaseCatalog();

  return (
    <main className="site-shell page-shell">
      <section className="page-intro">
        <p className="eyebrow">REGISTRO DURABLE / RELEASE HISTORY</p>
        <h1>Historial de versiones.</h1>
        <p>
          Una ficha por cada build que llegó al canal de Closed Beta. El estado distingue la versión vigente,
          las reemplazadas y cualquier build retirada.
        </p>
      </section>

      <section className="timeline-section" id="cambios">
        <div className="timeline-heading">
          <p className="section-kicker">CAMBIOS Y CORRECCIONES</p>
          <span>{catalog.releases.length} versiones registradas</span>
        </div>
        <div className="timeline">
          {catalog.releases.map((release) => <ReleaseCard key={release.version} release={release} />)}
        </div>
      </section>

      <div className="info-callout">
        <strong>Registro verificable.</strong>
        <span>Las versiones intermedias sin una ficha pública completa se incorporarán cuando sus notas exactas estén reconstruidas.</span>
      </div>
    </main>
  );
}
