# PRD: FuelMap — Precios de carburante en mapa (Italia)

> Product Requirements Document. Defines the what and why.
> This document is validated against external research before being finalized.
> It feeds into the RFC (technical design) — never skip straight to implementation.

## Status
Approved

## Date
2026-06-04

## Problem Statement
Los conductores en Italia carecen de una forma rápida, moderna y fiable de encontrar la gasolinera más barata cerca de ellos. Las apps existentes (p. ej. Prezzi Benzina) usan datos antiguos y una UX anticuada y poco intuitiva. Existen datos oficiales, gratuitos y actualizados a diario (MIMIT Open Data), pero no están expuestos de forma accesible para el usuario final. FuelMap cierra esa brecha con un mapa nativo iOS, rápido y limpio, sobre datos oficiales.

## Target Users
- Conductores particulares en Italia que quieren ahorrar en combustible (benzina, gasolio, GPL, metano).
- Sensibles al precio: commuters, familias, autónomos con vehículo.
- Usuarios de iPhone (iOS 17+). Mercado inicial Italia; arquitectura preparada para expandir a otros países más adelante.

## Research & Validation

| Source | Type | Key Insight |
|---|---|---|
| MIMIT Open Data (anagrafica_impianti_attivi.csv, prezzo_alle_8.csv) | Datos oficiales | ~22k impianti activos; precios con 3 decimales; `isSelf` self/servito; coordenadas "voluntarias" (pueden faltar). Actualización diaria ~08:00. Licencia IODL 2.0 (uso libre). |
| Osservaprezzi Carburanti (MIMIT) | Portal oficial | Comunicación obligatoria de precios por gestores (Ley 99/2009). Scraping frágil y zona gris legal → se descarta. |
| API wrapper `prezzi-carburante.onrender.com` (open source) | API de terceros | Búsqueda por lat/lng/radius/fuel ya resuelta, pero Render free tier = cold starts, sin SLA. Útil solo para prototipo → se descarta para producción. |
| Prezzi Benzina (competidor) | App existente | Datos percibidos como antiguos y UX anticuada. Oportunidad: diferenciación por UX moderna SwiftUI + velocidad + posible widget. |

**How research influenced the direction:**
La existencia de datos oficiales diarios hace innecesario un backend pesado de scraping. Se descarta tanto el scraping como depender de la API de terceros, optando por Supabase (PostgreSQL+PostGIS) alimentado por un sync diario en GitHub Actions: coste ~0€, control del esquema, búsqueda geoespacial eficiente. El diferencial frente a la competencia es UX y velocidad, no la fuente de datos.

## Goals
- Mostrar en un mapa nativo las gasolineras cercanas con su precio por tipo de combustible seleccionado.
- Permitir encontrar la más barata en el radio actual en < 3 segundos desde abrir la app.
- Datos siempre frescos (sync diario automático, sin intervención manual).
- UX moderna, accesible (Dynamic Type, VoiceOver) y rápida, claramente superior a la competencia.
- App gratuita monetizada con ads, sostenible a coste de infraestructura ~0€.

## Non-Goals (Explicit Scope Exclusions)
- Países distintos de Italia en v1 (sí: diseñar modelos/queries de forma agnóstica al país para no bloquear la expansión).
- Backend propio de servidor (se usa Supabase + GitHub Actions).
- Navegación turn-by-turn / routing (se delega a Apple Maps vía deep link "cómo llegar").
- Reportes de precios crowdsourced por usuarios en v1 (fuente única: MIMIT).
- Cuentas de usuario / login en v1 (favoritos en local con SwiftData).
- Suscripciones / compras in-app en v1 (solo ads).

## Requirements

### Functional
| ID | Requirement | Priority |
|---|---|---|
| F1 | Mapa centrado en la ubicación del usuario con pins de gasolineras y su precio del combustible seleccionado | Must have |
| F2 | Selector de tipo de combustible (benzina, gasolio, GPL, metano) que actualiza los precios mostrados | Must have |
| F3 | Filtro self-service / servito | Must have |
| F4 | Búsqueda por radio (estaciones en X km del centro del mapa / ubicación) | Must have |
| F5 | Detalle de estación: nombre, bandera, dirección, todos los combustibles con precio self/servito, hora de actualización | Must have |
| F6 | Clustering de pins cuando hay muchos juntos | Must have |
| F7 | Indicación visual de la estación más barata del radio actual | Should have |
| F8 | Banner de ads (AdMob) fuera del área del mapa | Must have |
| F9 | Permisos de ubicación con manejo de denegado / restringido | Must have |
| F10 | Deep link a Apple Maps para "cómo llegar" desde el detalle | Should have |
| F11 | Favoritos guardados en local (SwiftData) | Nice to have |
| F12 | Widget de iOS con la gasolinera más barata cerca | Nice to have |
| F13 | Ordenar lista de estaciones por precio o por distancia | Should have |

### Non-Functional
| ID | Requirement | Constraint |
|---|---|---|
| NF1 | Carga de estaciones del radio visible < 1.5 s en red móvil | Búsqueda geoespacial indexada (PostGIS GIST) en Supabase |
| NF2 | Datos no más antiguos de 24 h | Sync diario MIMIT ~08:00 vía GitHub Actions |
| NF3 | Coste de infraestructura ~0€ | Supabase free tier + GitHub Actions + MapKit nativo (sin límite) |
| NF4 | iOS 17+, Swift 6 strict concurrency completa | Estándar del equipo |
| NF5 | Accesibilidad: Dynamic Type + VoiceOver en todas las pantallas | HIG / estándar del equipo |
| NF6 | Funcionamiento robusto con coordenadas faltantes o datos parciales del MIMIT | Validación al ingerir + estados vacíos/error explícitos |
| NF7 | Cumplimiento App Store: privacidad (ubicación), ATT si aplica por AdMob, licencia IODL 2.0 atribuida | Requisito de publicación |

## Success Metrics
- Time-to-first-result (abrir app → ver precios en mapa) < 3 s en p50.
- Retención D7 ≥ 20% (benchmark inicial, a refinar).
- Crash-free sessions ≥ 99.5%.
- Reseñas App Store ≥ 4.3★ con menciones positivas a velocidad/UX vs competencia.
- Coste mensual de infraestructura ≤ 5€.

## Open Questions
- [x] **Endpoints MIMIT** — RESUELTO (2026-06-04, verificado en vivo). URLs estables:
  - `https://www.mimit.gov.it/images/exportCSV/anagrafica_impianti_attivi.csv`
  - `https://www.mimit.gov.it/images/exportCSV/prezzo_alle_8.csv`
  - **Separador `|` (pipe)** desde 2026-02-10 (antes `;`). `anagrafica`: 1ª línea `Estrazione del YYYY-MM-DD` (saltar) + header de 10 cols. `prezzo`: header `idImpianto|descCarburante|prezzo|isSelf|dtComu`. `descCarburante` con muchas variantes → requiere normalización. Licencia IODL 2.0.
- [x] **Supabase free tier** — RESUELTO. 500 MB DB / API ilimitada / 5 GB egress mes / PostGIS disponible. Volumen (~22k stations + precios) cabe holgado. Pausa por inactividad mitigada por el sync diario. A escala, vigilar egress (Pro $25/mes si hace falta).
- [x] **AdMob ATT/GDPR** — RESUELTO. Prompt ATT obligatorio con IDFA (`NSUserTrackingUsageDescription` + `requestTrackingAuthorization`). Italia=UE → consentimiento GDPR vía Google UMP SDK obligatorio en onboarding.
- [ ] ¿Frecuencia real de cambio de precios justifica sync 1×/día o conviene 2×? → revisar tras datos en producción (no bloqueante; v1 = 1×/día).
- [ ] ¿Ubicación del código de sync: monorepo `/backend` o repo separado? → decisión de RFC/ADR.
- [ ] Nombre comercial definitivo y disponibilidad en App Store (FuelMap es nombre de trabajo).

## References
- Conversación de ideación (Claude Desktop, 2026-06-03): panorama de fuentes de datos, arquitectura y hoja de ruta.
- MIMIT Open Data — Osservaprezzi Carburanti.
- `.claude/decisions/` — ADRs a crear durante el RFC.

---

> **Workflow:** Ideation → Research → **PRD (este doc)** → RFC → issues. No saltar a implementación.
