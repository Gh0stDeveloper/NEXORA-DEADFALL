import type { ReleaseRecord } from "@/lib/releases";

type Section = {
  title: string;
  items: string[];
  className: string;
};

export function ReleaseSections({ release }: { release: ReleaseRecord }) {
  const sections: Section[] = [
    { title: "Novedades", items: release.added, className: "section-added" },
    { title: "Cambios", items: release.changed, className: "section-changed" },
    { title: "Correcciones", items: release.fixed, className: "section-fixed" },
    { title: "Servidor y red", items: release.networking, className: "section-networking" },
    { title: "Android y rendimiento", items: release.android, className: "section-android" },
    { title: "Problemas conocidos", items: release.known_issues, className: "section-known" },
  ];

  return (
    <div className="release-sections">
      {sections
        .filter((section) => section.items.length > 0)
        .map((section) => (
          <section className={"notes-section " + section.className} key={section.title}>
            <h3>{section.title}</h3>
            <ul>
              {section.items.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ul>
          </section>
        ))}
    </div>
  );
}
