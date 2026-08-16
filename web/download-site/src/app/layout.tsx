import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = { title: 'NEXORA: DEADFALL — Closed Beta', description: 'Descarga la última Closed Beta de NEXORA: DEADFALL para Android.' };
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="es"><body>{children}</body></html>}
