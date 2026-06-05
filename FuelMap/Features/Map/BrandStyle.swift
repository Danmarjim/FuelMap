//
//  BrandStyle.swift
//  FuelMap
//
//  Created on 05/06/2026.
//

import SwiftUI

/// Estilo visual de una marca de gasolinera (FM-16). Normaliza el campo `Bandiera`
/// del MIMIT (texto, 325 variantes) a una marca conocida: color + monograma, y un
/// `assetName` opcional para soltar el logo oficial (SVG) en el catálogo más adelante.
/// Sin descargar/incrustar logos de marca (cuestión de marca registrada).
struct BrandStyle: Equatable {
    let displayName: String
    let monogram: String
    let color: Color
    let assetName: String?
    /// Fondo del chip detrás del logo (opción 1). Blanco para la mayoría; se
    /// sobreescribe en marcas cuyo logo es claro (p. ej. Eni amarillo → navy)
    /// para garantizar contraste en claro y oscuro. No es `color` (ese es el del
    /// monograma): un logo amarillo sobre un chip amarillo desaparecería.
    var logoBackground: Color = .white

    static func from(_ bandiera: String?) -> BrandStyle {
        let value = (bandiera ?? "").lowercased()
        if value.contains("agip") || value.contains("eni") { return eni }
        if value.contains("q8") { return q8 }
        if value.contains("esso") { return esso }
        if value.contains("tamoil") { return tamoil }
        if value.contains("shell") { return shell }
        if value.contains("api") || value.contains("ip") { return ip }
        if value.isEmpty || value.contains("pompe bianche") { return independent }
        let name = bandiera ?? "—"
        return BrandStyle(
            displayName: name,
            monogram: String(name.prefix(1)).uppercased(),
            color: .gray,
            assetName: nil
        )
    }

    // Top marcas en Italia por nº de impianti (datos MIMIT).
    static let eni = BrandStyle(displayName: "Eni", monogram: "E",
                                color: Color(red: 0.96, green: 0.78, blue: 0.08), assetName: "brand-eni",
                                logoBackground: Color(red: 0.05, green: 0.18, blue: 0.38))
    static let q8 = BrandStyle(displayName: "Q8", monogram: "Q8",
                               color: Color(red: 0.82, green: 0.12, blue: 0.16), assetName: "brand-q8")
    static let esso = BrandStyle(displayName: "Esso", monogram: "E",
                                 color: Color(red: 0.00, green: 0.33, blue: 0.66), assetName: "brand-esso")
    static let tamoil = BrandStyle(displayName: "Tamoil", monogram: "T",
                                   color: Color(red: 0.80, green: 0.00, blue: 0.15), assetName: "brand-tamoil")
    static let shell = BrandStyle(displayName: "Shell", monogram: "S",
                                  color: Color(red: 0.93, green: 0.79, blue: 0.00), assetName: "brand-shell")
    static let ip = BrandStyle(displayName: "IP", monogram: "IP",
                               color: Color(red: 0.00, green: 0.45, blue: 0.74), assetName: "brand-ip")
    static let independent = BrandStyle(displayName: "Indipendente", monogram: "",
                                        color: .gray, assetName: nil)
}
