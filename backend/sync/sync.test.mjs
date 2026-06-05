import { test } from "node:test";
import assert from "node:assert/strict";

import { normalizeFuel } from "./fuel-mapping.mjs";
import { parseAnagrafica, parsePrezzo } from "./parse.mjs";

test("normalizeFuel mapea variantes reales del MIMIT", () => {
  assert.equal(normalizeFuel("Benzina"), "benzina");
  assert.equal(normalizeFuel("Benzina WR 100"), "benzina");
  assert.equal(normalizeFuel("Blue Super"), "benzina");
  assert.equal(normalizeFuel("Gasolio"), "gasolio");
  assert.equal(normalizeFuel("Blue Diesel"), "gasolio");
  assert.equal(normalizeFuel("Hi-Q Diesel"), "gasolio");
  assert.equal(normalizeFuel("Supreme Diesel"), "gasolio");
  assert.equal(normalizeFuel("GPL"), "gpl");
  assert.equal(normalizeFuel("Metano"), "metano");
  assert.equal(normalizeFuel("GNL"), "metano");
  assert.equal(normalizeFuel("L-GNC"), "metano");
  assert.equal(normalizeFuel("HVOlution"), "hvo");
  assert.equal(normalizeFuel("HVO100"), "hvo");
  assert.equal(normalizeFuel("Gasolio HVO"), "hvo"); // hvo antes que gasolio
  assert.equal(normalizeFuel("F101"), "altro");
  assert.equal(normalizeFuel(""), "altro");
});

test("parseAnagrafica salta Estrazione+cabecera y valida coords", () => {
  const csv = [
    "Estrazione del 2026-06-04",
    "idImpianto|Gestore|Bandiera|Tipo Impianto|Nome Impianto|Indirizzo|Comune|Provincia|Latitudine|Longitudine",
    "1|Gestore A|Eni|Stradale|Distributore A|Via Roma 1|Roma|RM|41.9|12.5",
    "2|Gestore B|Q8|Stradale|Sin coords|Via X|Roma|RM||",
    "3|Gestore C|IP|Stradale|Cero|Via Y|Roma|RM|0|0",
  ].join("\n");

  const r = parseAnagrafica(csv);
  assert.equal(r.extractionDate, "2026-06-04");
  assert.deepEqual(r.stations.map((s) => s.id), [1]);
  assert.equal(r.stations[0].province, "RM");
  assert.equal(r.discarded, 2);
});

test("parsePrezzo normaliza, parsea self/precio y registra no-mapeadas", () => {
  const csv = [
    "Estrazione del 2026-06-04",
    "idImpianto|descCarburante|prezzo|isSelf|dtComu",
    "1|Benzina|1.879|1|03/06/2026 20:00:07",
    "1|Blue Diesel|1.959|0|03/06/2026 20:00:07",
    "1|F101|1.999|1|03/06/2026 20:00:07",
    "1|Benzina|0.1|1|03/06/2026 20:00:07",
  ].join("\n");

  const r = parsePrezzo(csv);
  assert.equal(r.prices.length, 3); // la de 0.1 € (basura) se descarta

  const benzina = r.prices.find((p) => p.fuelRaw === "Benzina");
  assert.equal(benzina.fuel, "benzina");
  assert.equal(benzina.isSelf, true);
  assert.equal(benzina.price, 1.879);
  assert.equal(benzina.communicatedAt, "2026-06-03T20:00:07");

  const diesel = r.prices.find((p) => p.fuelRaw === "Blue Diesel");
  assert.equal(diesel.fuel, "gasolio");
  assert.equal(diesel.isSelf, false);

  assert.ok(r.unmapped.has("F101"));
  assert.equal(r.skipped, 1);
});
