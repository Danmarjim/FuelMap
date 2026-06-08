//
//  Radius.swift
//  FuelMap
//
//  Created on 08/06/2026.
//

import CoreGraphics

/// Escala de radios de esquina del design system.
/// Fuente de verdad: `.claude/design/assets/tokens.css` (`--r-*`).
/// Para cápsulas (pin/tag) usar `Capsule()` en lugar de `pill`.
enum Radius {
    /// 8pt — controles.
    static let sm: CGFloat = 8
    /// 12pt — cards y chips.
    static let md: CGFloat = 12
    /// 16pt — sheets y cluster.
    static let lg: CGFloat = 16
    /// 20pt.
    static let xl: CGFloat = 20
    /// Cápsula completa (valor para `RoundedRectangle`; preferir `Capsule()`).
    static let pill: CGFloat = 999
}
