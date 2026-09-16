import type { Metadata } from "next";
import "./globals.css";
import { SiteHeader } from "./components/SiteHeader";

export const metadata: Metadata = {
  title: {
    default: "NEXORA: DEADFALL — Closed Beta",
    template: "%s — NEXORA: DEADFALL",
  },
  description:
    "Portal oficial de descarga, cambios y compatibilidad de NEXORA: DEADFALL para Android.",
  applicationName: "NEXORA: DEADFALL",
  icons: {
    icon: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="es">
      <body>
        <SiteHeader />
        {children}
      </body>
    </html>
  );
}
