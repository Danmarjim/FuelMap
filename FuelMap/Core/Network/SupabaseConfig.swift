//
//  SupabaseConfig.swift
//  FuelMap
//
//  Created on 05/06/2026.
//

import Foundation
import Supabase

/// Configuración de Supabase para el cliente iOS.
///
/// La `anonKey` es de **solo lectura** (protegida por RLS: anon solo SELECT/RPC),
/// está diseñada para incrustarse en el cliente. Si prefieres no versionarla,
/// muévela a un `.xcconfig`/Info.plist fuera de git.
enum SupabaseConfig {
    static let url = URL(string: "https://npbhmiaegxvmxntcppgd.supabase.co")!
    static let anonKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" +
        ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5wYmhtaWFlZ3h2bXhudGNwcGdkIiwi" +
        "cm9sZSI6ImFub24iLCJpYXQiOjE3ODA2NTkzMDIsImV4cCI6MjA5NjIzNTMwMn0" +
        ".zUA_uDHAm7ZAvew0XmoBqzSeiH1TMMCK-KYeRHUo0Z8"

    static let client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
}
