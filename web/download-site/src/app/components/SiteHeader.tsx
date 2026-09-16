"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";

const links = [
  { href: "/", label: "Inicio" },
  { href: "/#ultima-version", label: "Última versión" },
  { href: "/versiones#cambios", label: "Cambios y correcciones" },
  { href: "/compatibilidad", label: "Compatibilidad" },
  { href: "/beta", label: "Información de la beta" },
];

function isActive(href: string, pathname: string | null): boolean {
  const route = href.split("#")[0];
  if (route === "/") return pathname === "/";
  return pathname === route || Boolean(pathname?.startsWith(route + "/"));
}

export function SiteHeader() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  useEffect(() => {
    document.body.style.overflow = open ? "hidden" : "";
    return () => {
      document.body.style.overflow = "";
    };
  }, [open]);

  useEffect(() => {
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") setOpen(false);
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => window.removeEventListener("keydown", closeOnEscape);
  }, []);

  const closeMenu = () => setOpen(false);

  return (
    <header className="site-header">
      <div className="header-inner">
        <Link className="brand" href="/" onClick={closeMenu} aria-label="NEXORA DEADFALL, inicio">
          <span className="brand-mark" aria-hidden="true">N</span>
          <span>
            <strong>NEXORA</strong>
            <small>DEADFALL / OFFICIAL</small>
          </span>
        </Link>

        <nav className="desktop-nav" aria-label="Navegación principal">
          {links.map((link) => (
            <Link
              className={isActive(link.href, pathname) ? "nav-link active" : "nav-link"}
              href={link.href}
              key={link.href}
              onClick={closeMenu}
              aria-current={isActive(link.href, pathname) ? "page" : undefined}
            >
              {link.label}
            </Link>
          ))}
        </nav>

        <div className="header-side">
          <span className="beta-chip"><span className="status-dot" aria-hidden="true" /> CLOSED BETA</span>
          <button
            className="menu-trigger"
            type="button"
            aria-controls="mobile-menu"
            aria-expanded={open}
            aria-label={open ? "Cerrar menú" : "Abrir menú"}
            onClick={() => setOpen((value) => !value)}
          >
            <span className="menu-lines" aria-hidden="true">
              <span />
              <span />
              <span />
            </span>
          </button>
        </div>
      </div>

      {open && (
        <div className="menu-backdrop" role="presentation" onClick={closeMenu}>
          <aside
            className="mobile-menu"
            id="mobile-menu"
            aria-label="Menú principal"
            role="dialog"
            aria-modal="true"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="mobile-menu-head">
              <span className="section-kicker">NAVEGACIÓN</span>
              <button className="drawer-close" type="button" onClick={closeMenu} aria-label="Cerrar menú">
                <span className="close-lines" aria-hidden="true" />
              </button>
            </div>
            <nav className="drawer-nav" aria-label="Menú móvil">
              {links.map((link) => (
                <Link
                  className={isActive(link.href, pathname) ? "drawer-link active" : "drawer-link"}
                  href={link.href}
                  key={link.href}
                  onClick={closeMenu}
                  aria-current={isActive(link.href, pathname) ? "page" : undefined}
                >
                  <span>{link.label}</span>
                  <span className="drawer-arrow" aria-hidden="true">↗</span>
                </Link>
              ))}
            </nav>
            <div className="drawer-footer">
              <span>0.9.0-beta.5</span>
              <span>Android ARM64</span>
            </div>
          </aside>
        </div>
      )}
    </header>
  );
}
