# ADR-006: Capa premium con StoreKit 2 directo (sin RevenueCat)

> Fecha: 2026-07-17
> Estado: Aceptado
> Contexto: PREMIUM-001. Decisión sobre la implementación de la compra "sin anuncios".
> Motivación: monetizar sin depender solo de ads, sin arrastrar la complejidad de un SDK de suscripciones para un producto de un único no-consumible.

---

## 1. Contexto

FuelMap es gratis con ads (AdMob). El usuario quiere una vía de ingreso adicional que no dependa de eCPM ni de trackear al usuario. La opción más simple para una utility de uso puntual es un pago único que elimina los anuncios de toda la app.

## 2. Decisión

**StoreKit 2 directo**, envuelto en un `PurchaseClient` (`@Dependency`), sin SDKs de terceros.

- No-consumible único: `com.danmarjim.fuelmap.premium.noads` (~€3,99).
- `Transaction.currentEntitlements` + `Transaction.updates` cubren compra, restore entre dispositivos, family sharing y refunds sin servidor propio.
- Cache síncrona del entitlement (`LockIsolated<Bool>` + listener), mismo patrón que `LocationClient.authorizationStatus`.
- El entitlement se resuelve **antes** del flujo de consentimiento (UMP/ATT) en `AppFeature.onAppear`: un usuario premium nunca ve el formulario GDPR ni el prompt de tracking que no le corresponden.
- Favoritos siguen gratis e ilimitados — no se capan para forzar la compra (es el gancho de retención de la app free).

## 3. Consecuencias

### Archivos creados
- `Core/Purchases/PurchaseClient.swift` + `PurchaseStore.swift`.
- `Features/Premium/PaywallFeature.swift` + `PaywallView.swift`.
- `Features/Settings/SettingsView.swift` (entry point + atribución IODL 2.0).
- `FuelMap.storekit` (config local de testing, sin cuenta de sandbox).
- `FuelMapTests/{PremiumTests,PurchaseStoreTests,PaywallFeatureTests}.swift`.

### Riesgo aceptado
- **Pago único = techo de LTV.** Correcto para una utility de uso puntual (eCPM banner Italia ~€1–4/año por usuario vs. ~10 años de ese ingreso cobrados hoy). Si el roadmap gira a suscripción o a Android, reevaluar RevenueCat *antes* de tener base instalada de compradores — migrar entitlements ya vendidos es el coste que se evita eligiendo bien ahora.
- **Refund/family sharing** dejan el entitlement obsoleto si no se escucha `Transaction.updates` — cubierto (P2: refund reactiva ads + re-pide consent).
- **PLA sin aceptar** (Paid Applications Agreement) bloquea sandbox/producción — no bloquea desarrollo (`.storekit` local), sí bloquea TestFlight. Acción pendiente del usuario.

### No incluido (decisión explícita)
- RevenueCat u otro SDK de suscripciones/entitlements.
- Suscripciones, tiers múltiples, paywall A/B testing.
- Cap de favoritos u otras features detrás del paywall v1.

## 4. Alternativas consideradas

- **Opción A (elegida)**: StoreKit 2 directo. Cero dependencias nuevas, cubre el 100% del caso de uso (un no-consumible), coherente con "sin backend propio".
- **Opción B (rechazada)**: RevenueCat. Resuelve problemas que no tenemos (renovaciones, churn, grace periods, entitlements cross-platform) a cambio de un SDK, una cuenta externa y ~1% de fee. Se reevalúa si entra Android o suscripciones.

## 5. Referencias
- Plan de ejecución (archivado): `.claude/plan-archive/PREMIUM-001.md`
- PHASE_LOG: entrada "PREMIUM-001 — Capa premium (StoreKit 2)"
