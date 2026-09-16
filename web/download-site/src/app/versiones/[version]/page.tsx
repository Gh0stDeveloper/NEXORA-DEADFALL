import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { IntegrityBlock } from "../../components/IntegrityBlock";
import { ReleaseFacts } from "../../components/ReleaseFacts";
import { ReleaseSections } from "../../components/ReleaseSections";
import { ReleaseStatus } from "../../components/ReleaseStatus";
import {
  findRelease,
  getReleaseCatalog,
  type ReleaseRecord,
} from "@/lib/releases";

export const dynamic = "force-dynamic";

export async function generateStaticParams() {
  const catalog = await getReleaseCatalog();
  return catalog.releases.map((release) => ({ version: release.version }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ version: string }>;
}): Promise<Metadata> {
  const { version } = await params;
  const release = findRelease(await getReleaseCatalog(), version);
  return {
    title: release ? release.version + " · " + release.summary : "Versión no encontrada",
    description: release?.summary ?? "La versión solicitada no existe en el historial público.",
  };
}

export default async function VersionDetailPage({
  params,
}: {
  params: Promise<{ version: string }>;
}) {
  const { version } = await params;
  const release = findRelease(await getReleaseCatalog(), version);
  if (!release) notFound();

  return (
    <main className="site-shell page-shell detail-shell">
      <Link className="back-link" href="/versiones">Volver al historial</Link>
      <section className="detail-hero">
        <div>
          <p className="eyebrow">{release.channel.replace("_", " ")} / VERSION {release.version_code}</p>
          <div className="detail-title-row">
            <h1>{release.version}</h1>
            <ReleaseStatus status={release.status} />
          </div>
          <p className="detail-summary">{release.summary}</p>
        </div>
        <div className="detail-action">
          {release.download_available && release.download ? (
            <a className="button button-primary" href={release.download}>Descargar este APK</a>
          ) : (
            <span className="availability-note">APK histórico no disponible</span>
          )}
        </div>
      </section>

      <div className="release-data-grid detail-data-grid">
        <ReleaseFacts release={release} />
        <IntegrityBlock release={release} />
      </div>

      <ReleaseSections release={release} />

      <section className="detail-compatibility">
        <div>
          <p className="section-kicker">COMPATIBILIDAD</p>
          <h2>Contrato de la versión</h2>
        </div>
        <dl className="contract-grid">
          <div><dt>Canal</dt><dd>{release.channel}</dd></div>
          <div><dt>Protocolo</dt><dd>{release.protocol ?? "No disponible"}</dd></div>
          <div><dt>Contenido</dt><dd>{release.content_version ?? "No disponible"}</dd></div>
          <div><dt>Cliente mínimo</dt><dd>{release.min_client_version_code ?? "No disponible"}</dd></div>
          <div><dt>Cliente máximo</dt><dd>{release.max_client_version_code ?? "No disponible"}</dd></div>
          <div><dt>Arquitectura</dt><dd>{release.compatibility.architecture}</dd></div>
        </dl>
      </section>
    </main>
  );
}
