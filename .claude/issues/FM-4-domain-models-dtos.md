# FM-4: Modelos de dominio + DTOs + mapeo

> Derivado de RFC-001 §2.2, §3.2. Self-contained.

## Description
Definir los modelos de dominio Swift (`Station`, `FuelPrice`, `FuelType`, `Coordinate`) y los DTOs `Decodable` de la respuesta de la RPC, con el mapeo DTO→Model que descarta coordenadas inválidas.

Complexity: S
Dependencies: FM-1

## Files to Modify
- `Core/Models/Station.swift`, `Core/Models/FuelPrice.swift`, `Core/Models/FuelType.swift`, `Core/Models/Coordinate.swift` (nuevos).
- `Core/Network/DTOs/NearbyStationRowDTO.swift` (nuevo) — fila de `nearby_stations`.
- `Core/Network/DTOs/StationMapper.swift` (nuevo) — agrupa filas por estación → `[Station]`.

## Technical Specification (from RFC)
**Source:** RFC §2.2 (modelos), §3.1 (forma de la fila RPC), §3.2 (mapeo).

```swift
enum FuelType: String, Sendable, CaseIterable { case benzina, gasolio, gpl, metano, hvo, altro }
struct Coordinate: Equatable, Sendable { let latitude: Double; let longitude: Double }
struct FuelPrice: Equatable, Sendable { let fuel: FuelType; let price: Decimal; let isSelf: Bool; let communicatedAt: Date? }
struct Station: Identifiable, Equatable, Sendable {
    let id: Int; let name: String; let brand: String?; let address: String?
    let municipality: String?; let province: String?
    let coordinate: Coordinate; let prices: [FuelPrice]
    var cheapest: FuelPrice? { prices.min { $0.price < $1.price } }
}
```

- DTOs **`Decodable`** (nunca `Codable`), `.convertFromSnakeCase`.
- La RPC devuelve filas planas (una por estación×combustible) → `StationMapper` agrupa por `id`.
- Filas con lat/lng inválidas (nil/0/fuera de rango) se descartan en el mapeo (NF6).

## What NOT to Do
- Do NOT usar `Codable`.
- Do NOT hacer llamadas de red aquí (es FM-5).
- Do NOT mapear combustible desde texto crudo (ya viene normalizado del backend, ADR-003).

## Tests to Add
```swift
@Test func mapper_groupsRowsByStation()
@Test func mapper_discardsInvalidCoordinates()
@Test func station_cheapest_returnsMinPrice()
@Test func fuelType_decodesAllCases()
```

Mock/stub strategy: fixtures JSON de filas RPC.

## Status: DONE (2026-06-04)

> Añadidos sobre el plan original: `JSONDecoder.fuelMap` (decoder compartido), `ISO8601` (fechas tolerantes a fracciones), helpers `Decimal.rounded`/`String.nilIfEmpty`. Distancia (`distance_m`) NO se incorpora a `Station` (se siguió RFC §2.2 estrictamente; FM-10 la tratará).

## Acceptance Criteria
- [x] Modelos `Sendable`/`Equatable` definidos según RFC §2.2 (`Station`, `FuelPrice`, `FuelType`, `Coordinate`).
- [x] DTO `NearbyStationRowDTO` **`Decodable`** decodifica la fila RPC (snake_case → camelCase).
- [x] `StationMapper` agrupa por estación y descarta coords inválidas (nulas/(0,0)/fuera de rango).
- [x] `Station.cheapest` correcto.
- [x] Tests pass: 7 nuevos (StationMapperTests×5, FuelTypeTests×2); 8 totales. SwiftLint 0.

## References
- RFC: §2.2, §3.1, §3.2
