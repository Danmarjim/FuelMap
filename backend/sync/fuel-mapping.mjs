// Normalización de descCarburante → FuelType (ADR-003).
// Conjunto cerrado que consume el cliente iOS; `altro` es el fallback.

export const FUEL_TYPES = ["benzina", "gasolio", "gpl", "metano", "hvo", "altro"];

/**
 * Mapea el texto libre `descCarburante` del MIMIT a una categoría normalizada.
 * Orden importa: HVO antes que gasolio/diesel (p. ej. "Gasolio HVO" → hvo);
 * gas natural (metano/GNL/GNC) antes que el resto.
 */
export function normalizeFuel(desc) {
  const s = (desc ?? "").toLowerCase();
  if (s.includes("hvo")) return "hvo";
  if (s.includes("gpl")) return "gpl";
  if (s.includes("metano") || s.includes("gnl") || s.includes("gnc")) return "metano";
  if (s.includes("gasolio") || s.includes("diesel")) return "gasolio";
  if (s.includes("benzina") || s.includes("super")) return "benzina";
  return "altro";
}
