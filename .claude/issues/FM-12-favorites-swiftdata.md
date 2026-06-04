# FM-12: Favoritos en local (SwiftData) [Nice to have]

> Derivado de RFC-001 §4 (PRD F11). Self-contained.

## Description
Permitir marcar estaciones como favoritas, persistidas localmente con SwiftData, y un acceso rápido a ellas. Funcionalidad Nice-to-have de v1.

Complexity: M
Dependencies: FM-9

## Files to Modify
- `Core/Persistence/FavoriteStation.swift` (nuevo) — `@Model` SwiftData.
- `Core/Persistence/FavoritesClient.swift` (nuevo) — `@Dependency` (add/remove/list/isFavorite).
- `Features/StationDetail/StationDetailFeature.swift` — acción toggle favorito.
- `App/FuelMapApp.swift` — `modelContainer`.

## Technical Specification (from RFC)
**Source:** RFC §4 (FM-12); PRD F11. SwiftData (iOS 17+).

```swift
@Model final class FavoriteStation {
    @Attribute(.unique) var id: Int
    var name: String; var latitude: Double; var longitude: Double
    var addedAt: Date
}
```

- `FavoritesClient` envuelve el `ModelContext` (operaciones en `@MainActor` o `ModelActor`).
- Toggle desde el detalle; estado de favorito reflejado en el mapa/detalle.

## What NOT to Do
- Do NOT sincronizar a la nube ni requerir login (v1 local-only).
- Do NOT bloquear el arranque por la carga de favoritos.

## Tests to Add
```swift
@Test func favorites_add_thenIsFavoriteTrue()
@Test func favorites_remove_thenIsFavoriteFalse()
@Test func favorites_list_returnsAdded()
```

Mock/stub strategy: `ModelContainer` en memoria (`isStoredInMemoryOnly: true`) para tests; `testValue` del client.

## Acceptance Criteria
- [ ] Marcar/desmarcar favorito persiste entre lanzamientos.
- [ ] Lista de favoritos accesible.
- [ ] Tests pass (container en memoria).

## References
- RFC: §4; PRD F11
- Skill: core-data-expert / SwiftData
