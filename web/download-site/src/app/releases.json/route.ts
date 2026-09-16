import { getReleaseCatalog } from "@/lib/releases";

export const dynamic = "force-dynamic";

export async function GET() {
  const catalog = await getReleaseCatalog();
  return Response.json(catalog, {
    headers: {
      "Cache-Control": "no-cache",
    },
  });
}
