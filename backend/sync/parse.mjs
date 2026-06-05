// Parseo de los CSV del MIMIT (separador "|" desde 2026-02-10).
// Ambos ficheros traen una 1ª línea "Estrazione del YYYY-MM-DD" + una línea de
// cabecera; los datos empiezan tras la cabecera (RFC §6.3).

import { normalizeFuel } from "./fuel-mapping.mjs";

export function extractionDate(text) {
  const first = text.split(/\r?\n/, 1)[0] ?? "";
  const match = first.match(/Estrazione del (\d{4}-\d{2}-\d{2})/);
  return match ? match[1] : null;
}

// Líneas de datos: a partir de la cabecera (la que empieza por "idImpianto").
function dataLines(text) {
  const lines = text.split(/\r?\n/);
  const headerIdx = lines.findIndex((l) => l.toLowerCase().startsWith("idimpianto"));
  const start = headerIdx >= 0 ? headerIdx + 1 : 0;
  return lines.slice(start).filter((l) => l.trim().length > 0);
}

function clean(value) {
  const trimmed = (value ?? "").trim();
  return trimmed.length ? trimmed : null;
}

// Coords válidas: presentes, en rango mundial (escalabilidad) y no (0,0) (NF6).
function validCoord(lat, lng) {
  return Number.isFinite(lat) && Number.isFinite(lng)
    && (lat !== 0 || lng !== 0)
    && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}

// "DD/MM/YYYY HH:MM:SS" → "YYYY-MM-DDTHH:MM:SS" (naive, hora local Europe/Rome).
// Nota: sin offset de zona horaria; refinar si la precisión TZ importa.
function parseDtComu(value) {
  const m = (value ?? "").trim().match(/^(\d{2})\/(\d{2})\/(\d{4})\s+(\d{2}):(\d{2}):(\d{2})$/);
  if (!m) return null;
  const [, dd, mm, yyyy, hh, mi, ss] = m;
  return `${yyyy}-${mm}-${dd}T${hh}:${mi}:${ss}`;
}

/** anagrafica_impianti_attivi.csv → estaciones con coords válidas. */
export function parseAnagrafica(text) {
  const stations = [];
  let discarded = 0;
  let malformed = 0;

  for (const line of dataLines(text)) {
    const f = line.split("|");
    if (f.length < 10) { malformed++; continue; }
    const id = parseInt(f[0], 10);
    if (!Number.isFinite(id)) { malformed++; continue; }
    const latitude = parseFloat(f[8]);
    const longitude = parseFloat(f[9]);
    if (!validCoord(latitude, longitude)) { discarded++; continue; }

    stations.push({
      id,
      manager: clean(f[1]),
      brand: clean(f[2]),
      type: clean(f[3]),
      name: clean(f[4]),
      address: clean(f[5]),
      municipality: clean(f[6]),
      province: clean(f[7]),
      latitude,
      longitude,
    });
  }

  return { extractionDate: extractionDate(text), stations, discarded, malformed };
}

/** prezzo_alle_8.csv → precios normalizados. `unmapped`: variantes que cayeron a `altro`. */
export function parsePrezzo(text) {
  const prices = [];
  const unmapped = new Map();
  let malformed = 0;
  let skipped = 0;

  for (const line of dataLines(text)) {
    const f = line.split("|");
    if (f.length < 5) { malformed++; continue; }
    const stationId = parseInt(f[0], 10);
    const fuelRaw = clean(f[1]);
    const price = parseFloat(f[2]);
    if (!Number.isFinite(stationId) || !fuelRaw || !Number.isFinite(price) || price <= 0) {
      skipped++;
      continue;
    }
    const fuel = normalizeFuel(fuelRaw);
    if (fuel === "altro") unmapped.set(fuelRaw, (unmapped.get(fuelRaw) ?? 0) + 1);

    prices.push({
      stationId,
      fuel,
      fuelRaw,
      price,
      isSelf: f[3].trim() === "1",
      communicatedAt: parseDtComu(f[4]),
    });
  }

  return { prices, unmapped, malformed, skipped };
}
