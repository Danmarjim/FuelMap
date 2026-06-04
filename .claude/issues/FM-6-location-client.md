# FM-6: LocationClient (CoreLocation) + manejo de permisos

> Derivado de RFC-001 §3.3, §6.1. Self-contained.

## Description
Implementar `LocationClient` como `@Dependency` que envuelve `CLLocationManager`, expone estado de autorización y ubicación actual vía async/await, y maneja denegado/restringido sin bloquear el main actor.

Complexity: M
Dependencies: FM-1

## Files to Modify
- `Core/Location/LocationClient.swift` (nuevo) — struct de dependencia + live/test values.
- `Info.plist` — `NSLocationWhenInUseUsageDescription` (it/es/en).

## Technical Specification (from RFC)
**Source:** RFC §3.3, §6.1.

```swift
struct LocationClient: Sendable {
    var authorizationStatus: @Sendable () -> CLAuthorizationStatus
    var requestWhenInUse: @Sendable () async -> CLAuthorizationStatus
    var currentLocation: @Sendable () async throws -> Coordinate
}
```

- `notDetermined` → solicitar `when in use`.
- `denied/restricted` → la app centra en región por defecto (centro de Italia / última) y muestra CTA a Ajustes (la lógica de UI vive en MapFeature, FM-7).
- `authorized` → entregar ubicación.
- `CLLocationManager` no es Sendable: envolver con `AsyncStream`/continuations en un contexto aislado (`@MainActor` o actor dedicado). No bloquear el main actor.

## What NOT to Do
- Do NOT pedir `always` authorization (solo when-in-use).
- Do NOT poner lógica de mapa aquí (es FM-7).
- Do NOT usar Combine.

## Tests to Add
```swift
@Test func locationClient_notDetermined_requestsAuthorization()
@Test func locationClient_denied_currentLocationThrows()
```

Mock/stub strategy: `testValue` con estados de autorización y ubicación inyectables.

## Acceptance Criteria
- [ ] `requestWhenInUse` devuelve el estado tras la decisión del usuario.
- [ ] `currentLocation` entrega `Coordinate` cuando hay permiso; lanza si denegado.
- [ ] Sin warnings de concurrencia Swift 6.
- [ ] `Info.plist` con descripción de uso localizada.
- [ ] Tests pass.

## References
- RFC: §3.3, §6.1
