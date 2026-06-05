# FM-16: Badges de marca de gasolinera

Derivado de ideación UX (2026-06-05). El MIMIT solo da `Bandiera` (texto, 325 variantes; top: Eni/Agip, IP/Api, Q8, Esso, Tamoil + "Pompe Bianche" sin marca).

## Scope
- `BrandStyle`: normaliza `Bandiera` → marca conocida (color + monograma + assetName opcional) + fallback genérico. Pura, testeable.
- Detalle: badge de marca prominente (color + monograma; logo real si hay asset en bundle).
- Marker: chip de marca pequeño en el pin.
- **Sin scraping de logos** (marca registrada): color+monograma ahora; arquitectura lista para soltar SVGs oficiales luego (asset por marca).

## Status: DONE (2026-06-05)
> BrandStyle + BrandBadge; monograma en marker, badge en detalle. Color+monograma (logos reales = drop-in via asset). Tests BrandStyleTests.

## Acceptance
- [ ] `BrandStyle.from(_:)` mapea las top y cae a genérico; tests.
- [ ] Badge en detalle + chip en marker.
