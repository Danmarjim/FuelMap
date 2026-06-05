# FM-18: Color de precio por terciles (heat map)

Derivado de ideación UX (idea del usuario) — equivalente al heat map de GasBuddy.

## Scope
- `PriceTiers` (pura): de los precios más baratos del set calcula umbrales por terciles → `.low/.mid/.high` (verde/naranja/rojo).
- `StationPin`: fondo de la cápsula por tier (sustituye azul/verde actual). La más barata mantiene un distintivo (estrella).
- `ClusterPin`: tinte por el tier de su precio más barato.

## Acceptance
- [ ] `PriceTiers.tier(for:)` reparte por terciles; maneja N pequeño/empates; tests.
- [ ] Pines y clusters coloreados por valor.
