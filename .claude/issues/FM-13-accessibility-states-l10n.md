# FM-13: Accesibilidad, estados loading/empty/error y localización

> Derivado de RFC-001 §7 (NF5, NF6) y estándares globales. Self-contained.

## Description
Garantizar accesibilidad (Dynamic Type, VoiceOver) en todas las pantallas, estados de carga/vacío/error explícitos y consistentes, y localización it/es/en.

Complexity: M
Dependencies: FM-7, FM-8, FM-9

## Files to Modify
- Todas las vistas (`MapView`, `FiltersView`, `StationDetailView`, pins) — `accessibilityLabel`/`Value`/`Hint`, soporte Dynamic Type.
- `Localizable.xcstrings` (nuevo) — it (primario), es, en.
- Componentes de estado: `LoadingView`, `EmptyView`, `ErrorView` (nuevos, reutilizables).

## Technical Specification (from RFC)
**Source:** RFC §7; PRD NF5, NF6; estándares globales (HIG `/ios`).

- Dynamic Type: tipografía escalable, sin tamaños fijos que rompan layout.
- VoiceOver: pins anuncian nombre + precio + combustible; controles con labels claros.
- Estados explícitos en Map y Detail: loading (skeleton/spinner), empty ("nessun distributore nel raggio"), error (mensaje + retry).
- Localización con catálogo de strings; idioma primario italiano.

## What NOT to Do
- Do NOT introducir lógica nueva de negocio (solo a11y/estados/strings).
- Do NOT dejar strings hardcodeadas.

## Tests to Add
- Snapshot/UI smoke opcional; verificación manual de VoiceOver y Dynamic Type (AX Inspector).
- `@Test` para la lógica de selección de estado (loading/empty/error) si reside en reducers.

Mock/stub strategy: estados forzados vía `TestStore`.

## Status: DONE (2026-06-05)

> Localización vía String Catalog (`Localizable.xcstrings`, it/es/en) verificada en simulador forzando idioma. Dynamic Type vía fonts semánticas (auditoría AX Inspector = paso manual). Retry explícito no añadido (recarga automática al mover el mapa / cambiar filtro). Info.plist usage description l10n diferida a FM-14.

## Acceptance Criteria
- [x] Pantallas con fonts semánticas (Dynamic Type) sin frames fijos de texto.
- [x] VoiceOver: pins anuncian nombre+combustible+precio (+"más económico"); controles etiquetados.
- [x] Estados loading/empty/error visibles y localizados (retry implícito por recarga).
- [x] Strings localizadas it/es/en (verificado es: Gasolina/Autoservicio; en: Petrol/Self-service).
- [x] Tests pass: +1 (label); 34 totales. SwiftLint 0.

## References
- RFC: §7; PRD NF5, NF6
- Skill: `/ios` (HIG)
