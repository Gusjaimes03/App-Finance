import SwiftUI
import UIKit

/// Paleta de Mi plata: azul noche del llano con el amarillo del sol de la sabana.
enum Theme {
    static let fondo = dynamic(light: "f2f4f9", dark: "0b0f1d")
    static let panel = dynamic(light: "ffffff", dark: "141a2e")
    static let texto = dynamic(light: "121a30", dark: "e9edf7")
    static let gris = dynamic(light: "5b647c", dark: "9ba4bd")
    static let linea = dynamic(light: "e1e5ee", dark: "262f4a")
    static let acento = dynamic(light: "2c56e0", dark: "7d9bff")
    static let heroInicio = dynamic(light: "14204a", dark: "18265a")
    static let heroFin = dynamic(light: "1d2d63", dark: "22317a")
    static let sol = dynamic(light: "ffb627", dark: "ffc04d")
    static let verde = dynamic(light: "128552", dark: "4cc98d")
    static let ambar = dynamic(light: "a86400", dark: "f2b14f")
    static let rojo = dynamic(light: "cc3027", dark: "ff7d72")

    static let radio: CGFloat = 18

    static var heroGradient: LinearGradient {
        LinearGradient(colors: [heroInicio, heroFin], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Color que cambia solo entre modo claro y oscuro.
    static func dynamic(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension UIColor {
    convenience init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red = CGFloat((value & 0xFF0000) >> 16) / 255
        let green = CGFloat((value & 0x00FF00) >> 8) / 255
        let blue = CGFloat(value & 0x0000FF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}

extension Color {
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }

    /// Colores en rotación para las categorías que cree el usuario.
    static let coloresNuevos = ["0e7490", "be185d", "4d7c0f", "6d28d9", "c2410c", "0f766e", "a21caf"]
}

/// Tarjeta blanca redondeada sobre el fondo gris azulado.
struct Panel: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.radio, style: .continuous)
                    .fill(Theme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radio, style: .continuous)
                    .strokeBorder(Theme.linea, lineWidth: 1)
            )
    }
}

extension View {
    func panel(padding: CGFloat = 16) -> some View {
        modifier(Panel(padding: padding))
    }

    /// Ancho máximo de una columna, como en la versión web.
    func columna() -> some View {
        frame(maxWidth: 576)
    }
}
