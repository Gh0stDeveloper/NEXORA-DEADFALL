import Link from "next/link";
import { getCurrentRelease, getReleaseCatalog } from "@/lib/releases";
import { ReleaseSections } from "../components/ReleaseSections";

export const dynamic = "force-dynamic";

export default async function BetaPage() {
  const current = getCurrentRelease(await getReleaseCatalog());

  return (
    <main className="site-shell page-shell">
      <section className="page-intro">
        <p className="eyebrow">INFORMACIÓN DE LA BETA</p>
        <h1>Prueba el brote con contexto.</h1>
        <p>Consulta qué está incluido, qué sigue en validación y cómo interpretar el estado de esta distribución.</p>
      </section>

      <section className="beta-panel">
        <div className="beta-panel-top">
          <div>
            <p className="section-kicker">CLOSED BETA ACTUAL</p>
            <h2>{current.version}</h2>
          </div>
          <span className="beta-panel-code">BUILD {current.version_code}</span>
        </div>
        <p>{current.summary}</p>
        <div className="beta-checklist">
          <span><i aria-hidden="true" />Solo</span>
          <span><i aria-hidden="true" />Duo online</span>
          <span><i aria-hidden="true" />Reconexión</span>
          <span><i aria-hidden="true" />3 / 4 jugadores</span>
        </div>
      </section>

      <ReleaseSections release={current} />

      <div className="info-callout warning-callout">
        <strong>Recuerda.</strong>
        <span>Es una beta de prueba: el rendimiento, la temperatura y la estabilidad pueden variar según el dispositivo y la red.</span>
      </div>
      <Link className="text-link" href={"/versiones/" + current.version}>
        Abrir detalles de {current.version} <span aria-hidden="true">↗</span>
      </Link>
    </main>
  );
}
