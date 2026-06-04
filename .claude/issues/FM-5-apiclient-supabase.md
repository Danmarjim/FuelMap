# FM-5: APIClient sobre supabase-swift

> Derivado de RFC-001 §3.2. Self-contained.

## Description
Implementar `APIClient` como `@Dependency` de TCA usando `supabase-swift`, exponiendo `nearbyStations` y `stationDetail`, con errores tipados (`APIError`) y mapeo DTO→Model. Es la única puerta de la app hacia los datos.

Complexity: M
Dependencies: FM-1, FM-2, FM-4

## Files to Modify
- `Core/Network/APIClient.swift` (nuevo) — struct de dependencia + `liveValue`/`testValue`.
- `Core/Network/APIError.swift` (nuevo).
- `Core/Network/SupabaseConfig.swift` (nuevo) — URL + anon key (read-only; sin secretos sensibles).

## Technical Specification (from RFC)
**Source:** RFC §3.2.

```swift
struct APIClient: Sendable {
    var nearbyStations: @Sendable (_ center: Coordinate, _ radiusKm: Double, _ fuel: FuelType, _ selfOnly: Bool) async throws -> [Station]
    var stationDetail: @Sendable (_ id: Int) async throws -> Station
}
enum APIError: Error, Equatable, Sendable { case network(String), decoding, unauthorized, server(Int), noResults }
```

- `nearbyStations` llama la RPC `nearby_stations` (FM-2) y mapea con `StationMapper` (FM-4).
- `stationDetail` consulta todas las filas de la estación (todos los combustibles).
- Errores de transporte/decoding/HTTP → `APIError` tipado en el límite del cliente.
- Usa la **anon key** (read-only). Nunca la service_role.
- Como `DependencyKey`: `liveValue` (Supabase real), `testValue` (unimplemented).

## What NOT to Do
- Do NOT poner lógica de UI/estado aquí.
- Do NOT usar la service_role key.
- Do NOT cachear en disco todavía (fuera de scope v1).

## Tests to Add
```swift
@Test func apiClient_nearby_mapsRowsToStations()      // con cliente Supabase fakeado
@Test func apiClient_mapsTransportErrorToAPIError()
@Test func apiClient_emptyResult_throwsNoResults()
```

Mock/stub strategy: protocolo/closure para la capa Supabase, inyectando respuestas JSON fixture.

## Status: PARCIAL — mock hecho (2026-06-04); real (supabase-swift) pendiente de FM-2/FM-3

> **Estrategia mock (petición del usuario):** `liveValue` = `APIClient.mock()` con `StationFixtures` (6 estaciones de Roma). Contrato + `APIError` + `testValue` listos. La implementación real sobre `supabase-swift` contra la RPC `nearby_stations` se completa cuando exista el backend (FM-2/FM-3): sustituir `liveValue`, sin cambiar el contrato. **Riesgo:** no enviar el mock a producción → swap obligatorio + verificación en FM-14.

## Acceptance Criteria
- [x] Contrato `APIClient` (`nearbyStations`, `stationDetail`) + `APIError` tipado.
- [x] `liveValue`/`previewValue` = mock (filtra por fuel/self, ordena por precio); `testValue` unimplemented.
- [x] Registrado en `DependencyValues`.
- [x] Tests pass: 5 nuevos (`APIClientTests`); 16 totales. SwiftLint 0.
- [ ] **(FM-2/FM-3)** `nearbyStations` contra la RPC real sobre Supabase poblado.
- [ ] **(FM-2/FM-3)** Errores de red/HTTP/decoding mapeados a `APIError` (cobertura con cliente fakeado).

## References
- RFC: §3.2, §3.1
- ADR-001
