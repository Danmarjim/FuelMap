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
const DOWNLOAD_TIMEOUT_MS = 60_000;
const DOWNLOAD_RETRIES = 3;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// UA de navegador: el WAF del MIMIT rechaza intermitentemente clientes no-browser
// (el UA por defecto de undici/node). No cuesta nada y esquiva esa regla.
const BROWSER_HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
  Accept: "text/csv,text/plain,*/*",
};

// `fetch failed` envuelve la causa real en error.cause; exponerla para diagnosticar
// (ECONNRESET / ETIMEDOUT / bloqueo por IP del servidor del MIMIT).
const causeOf = (error) => error?.cause?.code ?? error?.cause?.message ?? "";

// El endpoint del MIMIT es un servidor público inestable y filtra IPs de cloud
// extranjeras de forma intermitente. Reintenta con backoff; el rescate real ante
// un bloqueo por IP son los slots de cron extra (runner nuevo = IP nueva).
async function download(url) {
  let lastError;
  for (let attempt = 1; attempt <= DOWNLOAD_RETRIES; attempt++) {
    try {
      const res = await fetch(url, {
        headers: BROWSER_HEADERS,
        signal: AbortSignal.timeout(DOWNLOAD_TIMEOUT_MS),
      });
      if (!res.ok) throw new Error(`download ${url}: HTTP ${res.status}`);
      return await res.text();
    } catch (error) {
      lastError = error;
      if (attempt < DOWNLOAD_RETRIES) {
        const backoff = 2 ** (attempt - 1) * 2000; // 2s, 4s
        console.warn(`download ${url} falló (intento ${attempt}/${DOWNLOAD_RETRIES}): ${error.message} [${causeOf(error)}]; reintento en ${backoff}ms`);
        await sleep(backoff);
      }
    }
  }
  throw new Error(`download ${url}: ${lastError.message} [${causeOf(lastError)}] tras ${DOWNLOAD_RETRIES} intentos`);
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

// Idempotencia: con varios slots de cron al día, salta si YA hubo un sync OK hoy.
// Se basa en finished_at (no en extraction_date: el "Estrazione del" del MIMIT va
// con un día de retraso). Datos diarios → un éxito al día es suficiente.
// FORCE_SYNC=true (input manual) lo salta para poder validar la descarga bajo demanda.
async function alreadySyncedToday(supabase) {
  if (process.env.FORCE_SYNC === "true") return false;
  const todayStart = `${new Date().toISOString().slice(0, 10)}T00:00:00Z`; // medianoche UTC
  const { data, error } = await supabase
    .from("sync_runs")
    .select("id")
    .eq("status", "ok")
    .gte("finished_at", todayStart)
    .limit(1);
  if (error) {
    console.warn(`guard de idempotencia falló (sigo igualmente): ${error.message}`);
    return false;
  }
  return (data?.length ?? 0) > 0;
}

async function main() {
  const supabase = client();
  const startedAt = new Date().toISOString();
  const notes = [];

  if (await alreadySyncedToday(supabase)) {
    console.log("SKIP — ya existe un sync OK con la extracción de hoy");
    return;
  }

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
