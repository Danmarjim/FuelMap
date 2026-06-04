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

## Acceptance Criteria
- [ ] Todas las pantallas soportan Dynamic Type sin truncado roto.
- [ ] VoiceOver navega y anuncia precios/estaciones correctamente.
- [ ] Estados loading/empty/error visibles y con retry donde aplica.
- [ ] Strings localizadas it/es/en.
- [ ] Tests pass.

## References
- RFC: §7; PRD NF5, NF6
- Skill: `/ios` (HIG)
