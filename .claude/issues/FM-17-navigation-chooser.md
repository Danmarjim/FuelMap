# FM-17: Selector de navegación (Apple/Google/Waze)

Derivado de ideación UX. El líder (Prezzi Benzina) integra Google Maps + Waze.

## Scope
- En el detalle, "Indicazioni" abre un action sheet con las apps de navegación instaladas: Apple Maps / Google Maps (`comgooglemaps://`) / Waze (`waze://`).
- Detección con `UIApplication.canOpenURL` → `LSApplicationQueriesSchemes` en Info.plist.
- Si solo hay Apple Maps, abrir directo (sin sheet).

## Status: DONE (2026-06-05)
> NavApp (Apple/Google/Waze) + confirmationDialog con apps instaladas (LSApplicationQueriesSchemes). Tests NavAppTests.

## Acceptance
- [ ] URLs por proveedor correctas (destino lat,lng); solo se ofrecen las instaladas.
- [ ] Test de construcción de URLs.
