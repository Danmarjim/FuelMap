//
//  Typography.swift
//  FuelMap
//
//  Created on 08/06/2026.
//

import SwiftUI

/// Roles tipográficos del design system (SF Pro, sistema).
/// Fuente de verdad: `.claude/design/assets/tokens.css` (`.t-*`).
///
/// Cada rol se mapea a un text style nativo de iOS para heredar Dynamic Type;
/// el `weight` del diseño se aplica sobre él. Los números (precios/distancias)
/// usan dígitos tabulares vía `.monospacedDigit()`.
extension Font {
    /// 34 / Bold
    static let fmLargeTitle = Font.system(.largeTitle, weight: .bold)
    /// 28 / Bold
    static let fmTitle1 = Font.system(.title, weight: .bold)
    /// 22 / Bold
    static let fmTitle2 = Font.system(.title2, weight: .bold)
    /// 20 / Semibold
    static let fmTitle3 = Font.system(.title3, weight: .semibold)
    /// 17 / Semibold
    static let fmHeadline = Font.system(.headline)
    /// 17 / Regular
    static let fmBody = Font.system(.body)
    /// 16 / Regular
    static let fmCallout = Font.system(.callout)
    /// 15 / Regular
    static let fmSubheadline = Font.system(.subheadline)
    /// 13 / Regular
    static let fmFootnote = Font.system(.footnote)
    /// 12 / Regular
    static let fmCaption = Font.system(.caption)
    /// 11 / Medium
    static let fmCaption2 = Font.system(.caption2, weight: .medium)

    // MARK: - Números y precios (dígitos tabulares)

    /// Precio del pin (~15pt, semibold). La Dynamic Type se capa en la vista del pin
    /// con `.dynamicTypeSize(...DynamicTypeSize.large)` para no desbordar sobre el mapa.
    static let fmPinPrice = Font.system(.subheadline, weight: .semibold).monospacedDigit()
    /// Precio en filas de lista (~19pt, bold).
    static let fmPriceRow = Font.system(.title3, weight: .bold).monospacedDigit()
    /// Precio destacado en detalle (~18pt, bold).
    static let fmPriceDetail = Font.system(.body, weight: .bold).monospacedDigit()
}
