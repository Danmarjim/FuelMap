//
//  Elevation.swift
//  FuelMap
//
//  Created on 08/06/2026.
//

import SwiftUI

/// Niveles de elevación del design system. Levantan la UI flotante sobre el mapa.
/// Fuente de verdad: `.claude/design/assets/tokens.css` (`--e*`).
///
/// Las multi-sombra del CSS se aproximan a una `.shadow` de SwiftUI; en modo oscuro
/// la sombra se profundiza. El hairline/ring se aplica aparte en cada componente.
enum Elevation {
    case e1, e2, e3, pin, pinSelected, sheet
}

/// Parámetros de una sombra (radius ≈ blur CSS / 2).
private struct Shadow {
    let radius: CGFloat
    let offsetY: CGFloat
    let opacity: Double
}

private struct ElevationModifier: ViewModifier {
    let level: Elevation
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shadow = params
        return content.shadow(color: .black.opacity(shadow.opacity), radius: shadow.radius, x: 0, y: shadow.offsetY)
    }

    private var params: Shadow {
        let dark = scheme == .dark
        switch level {
        case .e1:          return Shadow(radius: 1, offsetY: 1, opacity: dark ? 0.50 : 0.12)
        case .e2:          return Shadow(radius: 3, offsetY: 2, opacity: dark ? 0.55 : 0.18)
        case .e3:          return Shadow(radius: 12, offsetY: 8, opacity: dark ? 0.60 : 0.22)
        case .pin:         return Shadow(radius: 4, offsetY: 3, opacity: dark ? 0.60 : 0.30)
        case .pinSelected: return Shadow(radius: 11, offsetY: 10, opacity: dark ? 0.70 : 0.38)
        case .sheet:       return Shadow(radius: 12, offsetY: -2, opacity: dark ? 0.50 : 0.16)
        }
    }
}

extension View {
    /// Aplica una sombra de elevación del design system.
    func elevation(_ level: Elevation) -> some View {
        modifier(ElevationModifier(level: level))
    }
}
