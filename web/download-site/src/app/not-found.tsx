import Link from "next/link";

export default function NotFound() {
  return (
    <main className="site-shell page-shell not-found">
      <p className="eyebrow">404 / REGISTRO NO ENCONTRADO</p>
      <h1>Esta versión no existe.</h1>
      <p>El enlace no corresponde a una versión publicada en el historial público.</p>
      <Link className="button button-secondary inline-button" href="/versiones">Volver al historial</Link>
    </main>
  );
}
