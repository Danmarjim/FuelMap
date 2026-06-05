// Sync diario MIMIT → Supabase (FM-3). Ejecutado por GitHub Actions.
// Descarga los CSV, parsea/normaliza/valida, upsert de stations y reemplazo de
// prices, y registra telemetría en sync_runs. Usa la service_role key (bypassa RLS).

import { createClient } from "@supabase/supabase-js";
import { parseAnagrafica, parsePrezzo } from "./parse.mjs";

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

const ANAGRAFICA_URL = "https://www.mimit.gov.it/images/exportCSV/anagrafica_impianti_attivi.csv";
const PREZZO_URL = "https://www.mimit.gov.it/images/exportCSV/prezzo_alle_8.csv";
const CHUNK = 1000;

async function download(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`download ${url}: HTTP ${res.status}`);
  return res.text();
}

function chunk(array, size) {
  const out = [];
  for (let i = 0; i < array.length; i += size) out.push(array.slice(i, i + size));
  return out;
}

function client() {
  if (!SUPABASE_URL || !SERVICE_KEY) {
    throw new Error("Faltan SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY");
  }
  return createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });
}

async function main() {
  const supabase = client();
  const startedAt = new Date().toISOString();
  const notes = [];

  const [anaText, prezzoText] = await Promise.all([download(ANAGRAFICA_URL), download(PREZZO_URL)]);
  const ana = parseAnagrafica(anaText);
  const prz = parsePrezzo(prezzoText);

  if (ana.stations.length === 0) throw new Error("anagrafica vacía tras el parseo");

  // ── Upsert stations ──
  const now = new Date().toISOString();
  const stationRows = ana.stations.map((s) => ({
    id: s.id,
    manager: s.manager,
    brand: s.brand,
    type: s.type,
    name: s.name,
    address: s.address,
    municipality: s.municipality,
    province: s.province,
    location: `SRID=4326;POINT(${s.longitude} ${s.latitude})`,
    country: "IT",
    updated_at: now,
  }));

  let stationsUpserted = 0;
  for (const part of chunk(stationRows, CHUNK)) {
    const { error } = await supabase.from("stations").upsert(part, { onConflict: "id" });
    if (error) throw new Error(`upsert stations: ${error.message}`);
    stationsUpserted += part.length;
  }

  // ── Reemplazo de prices (solo de estaciones conocidas; dedup por PK) ──
  const knownIds = new Set(ana.stations.map((s) => s.id));
  const seen = new Set();
  const priceRows = [];
  for (const p of prz.prices) {
    if (!knownIds.has(p.stationId)) continue;
    const key = `${p.stationId}|${p.fuelRaw}|${p.isSelf}`;
    if (seen.has(key)) continue;
    seen.add(key);
    priceRows.push({
      station_id: p.stationId,
      fuel: p.fuel,
      fuel_raw: p.fuelRaw,
      price: p.price,
      is_self: p.isSelf,
      communicated_at: p.communicatedAt,
    });
  }

  // Nota: delete + insert no es atómico (ventana breve). Aceptable para un job diario.
  const { error: delErr } = await supabase.from("prices").delete().gte("station_id", 0);
  if (delErr) throw new Error(`delete prices: ${delErr.message}`);

  let pricesInserted = 0;
  for (const part of chunk(priceRows, CHUNK)) {
    const { error } = await supabase.from("prices").insert(part);
    if (error) throw new Error(`insert prices: ${error.message}`);
    pricesInserted += part.length;
  }

  // ── Notas de observabilidad ──
  if (ana.discarded) notes.push(`coords inválidas descartadas: ${ana.discarded}`);
  if (prz.unmapped.size) {
    const top = [...prz.unmapped.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 20)
      .map(([k, v]) => `${k}(${v})`)
      .join(", ");
    notes.push(`fuel→altro: ${top}`);
  }

  await supabase.from("sync_runs").insert({
    started_at: startedAt,
    finished_at: new Date().toISOString(),
    stations_upserted: stationsUpserted,
    prices_upserted: pricesInserted,
    stations_discarded: ana.discarded,
    extraction_date: ana.extractionDate,
    status: "ok",
    notes: notes.join(" | ") || null,
  });

  console.log(
    `OK — extracción ${ana.extractionDate}: ${stationsUpserted} stations, ` +
      `${pricesInserted} prices, ${ana.discarded} descartadas`,
  );
}

main().catch(async (error) => {
  console.error("SYNC FAILED:", error.message);
  try {
    await client().from("sync_runs").insert({
      finished_at: new Date().toISOString(),
      status: "error",
      notes: error.message,
    });
  } catch {
    // best-effort; el fallo principal ya está logueado
  }
  process.exit(1);
});
