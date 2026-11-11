import SwiftUI
import UIKit

/// Sistema de diseño "Llano de noche" de Mi plata.
///
/// Azul noche como marca y tinte, el amarillo del sol de la sabana como acento escaso
/// (la cifra que importa, el día de hoy) y colores semánticos para entradas, avisos y
/// excesos. Ver docs/DISENO.md para las reglas de uso.
enum Theme {
    // MARK: Superficies

    /// Fondo de cada pantalla.
    static let fondo = dynamic(light: "F4F5F8", dark: "05070F")
    /// Tarjetas y grupos de filas (alias histórico de `superficie`).
    static let panel = dynamic(light: "FFFFFF", dark: "10152A")
    static let superficie = panel
    /// Hojas, menús flotantes y elementos sobre tarjetas.
    static let elevada = dynamic(light: "FFFFFF", dark: "171D36")
    /// Campos, chips y mosaicos dentro de una tarjeta.
    static let hundido = dynamic(light: "ECEEF3", dark: "1A2140")
    /// Separadores finos entre filas.
    static let linea = dynamic(light: "E3E6EE", dark: "232B4A")
    /// Pista de barras, anillos y donas.
    static let pista = dynamic(light: "E9ECF2", dark: "1C2342")

    // MARK: Texto

    static let texto = dynamic(light: "0E1428", dark: "F2F4FA")
    /// Texto secundario: subtítulos, fechas, etiquetas.
    static let gris = dynamic(light: "5A637A", dark: "A3ABC2")
    /// Texto terciario: marcadores, ejes, notas al pie. Nunca para información clave.
    static let grisClaro = dynamic(light: "8A92A8", dark: "6B7391")

    // MARK: Marca

    /// Único color interactivo: botones, enlaces, selección.
    static let acento = dynamic(light: "2B48D8", dark: "8EA6FF")
    static let acentoSuave = dynamic(light: "E7ECFC", dark: "1B2552")
    /// Texto o ícono encima de `acento`.
    static let sobreAcento = dynamic(light: "FFFFFF", dark: "0A1030")
    /// Relleno del botón flotante: en oscuro, el azul saturado (no el pastel) para que no
    /// sea lo más brillante de la pantalla. Siempre con ícono blanco.
    static let acentoFuerte = dynamic(light: "2B48D8", dark: "3F5FE8")

    /// Degradado de la tarjeta principal (azul noche).
    static let heroInicio = dynamic(light: "0C1433", dark: "0B1230")
    static let heroFin = dynamic(light: "1A2A6B", dark: "15225A")

    /// Sol de la sabana: solo para la cifra protagonista, el día de hoy y el CTA sobre oscuro.
    static let sol = dynamic(light: "FFB020", dark: "FFC247")
    static let solSuave = dynamic(light: "FFF1D1", dark: "3A2C0A")
    static let sobreSol = Color(hex: "1A1200", adaptar: false)

    // MARK: Semánticos

    /// Entradas de plata y estados buenos.
    static let verde = dynamic(light: "0B7D4C", dark: "4ED19A")
    static let verdeSuave = dynamic(light: "E3F5EC", dark: "0F2A20")
    /// "Ojo": cerca del límite, pronto vence.
    static let ambar = dynamic(light: "9A5B00", dark: "F5B651")
    static let ambarSuave = dynamic(light: "FDF0DC", dark: "33250C")
    /// Ámbar para rellenos (barras, anillos). El `ambar` normal es para texto.
    static let ambarRelleno = dynamic(light: "F0A019", dark: "F5B651")
    /// Solo para vencido, pasado del presupuesto o error. No para "salió plata".
    static let rojo = dynamic(light: "D1342B", dark: "FF7A70")
    static let rojoSuave = dynamic(light: "FCE6E4", dark: "3A1614")
    /// Cifra negativa sobre el hero azul noche (contraste > 7:1 en ambos modos).
    static let rojoSobreHero = Color(hex: "FF948C", adaptar: false)

    // MARK: Elevación

    /// Sombra de tarjetas: solo existe en modo claro.
    static let sombra = dynamic(light: "000000", lightAlpha: 0.06, dark: "000000", darkAlpha: 0)
    static let sombraCercana = dynamic(light: "000000", lightAlpha: 0.04, dark: "000000", darkAlpha: 0)
    /// Borde finísimo de tarjetas: solo existe en modo oscuro.
    static let bordeTarjeta = dynamic(light: "FFFFFF", lightAlpha: 0, dark: "FFFFFF", darkAlpha: 0.06)

    // MARK: Forma

    /// Radio de tarjetas (alias histórico).
    static let radio: CGFloat = Radio.tarjeta

    static var heroGradient: LinearGradient {
        LinearGradient(colors: [heroInicio, heroFin], startPoint: .top, endPoint: .bottomTrailing)
    }

    /// Color de relleno de una barra de avance según qué tan lleno va: tinte < 80 %, ámbar hasta 100 %, rojo encima.
    static func colorAvance(_ avance: Double) -> Color {
        if avance > 1 { return rojo }
        if avance >= 0.8 { return ambarRelleno }
        return acento
    }

    /// Color que cambia solo entre modo claro y oscuro.
    static func dynamic(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    static func dynamic(light: String, lightAlpha: CGFloat, dark: String, darkAlpha: CGFloat) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: dark).withAlphaComponent(darkAlpha)
                : UIColor(hex: light).withAlphaComponent(lightAlpha)
        })
    }
}

/// Espaciado en múltiplos de 4.
enum Espacio {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 20
    static let xl: CGFloat = 24
    /// Entre secciones de una pantalla.
    static let seccion: CGFloat = 28
    static let xxl: CGFloat = 32
    /// Margen lateral de cada pantalla.
    static let margen: CGFloat = 20
    /// Entre el título de una sección y su contenido.
    static let titulo: CGFloat = 10
}

/// Radios de esquina (siempre `.continuous`).
enum Radio {
    static let hero: CGFloat = 28
    static let tarjeta: CGFloat = 20
    static let mosaico: CGFloat = 14
    static let campo: CGFloat = 12
}

// MARK: Tipografía

extension Font {
    /// Cifra secundaria grande: 34 pt redondeada (escala con Dynamic Type).
    static let cifraGrande = Font.system(.largeTitle, design: .rounded).weight(.bold)
    /// Cifra de un dato (KPI, total de una fila destacada).
    static let cifraMedia = Font.system(.title3, design: .rounded).weight(.semibold)
    /// Cifra de una fila de lista.
    static let cifra = Font.system(.body, design: .rounded).weight(.semibold)
    /// Cifra pequeña (subtítulos con plata).
    static let cifraPequena = Font.system(.subheadline, design: .rounded).weight(.semibold)
    /// Sobrelínea en mayúsculas para grupos (usar con `.textCase(.uppercase)` y `.tracking(0.6)`).
    static let sobrelinea = Font.caption.weight(.semibold)
}

// MARK: Colores hexadecimales

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

    /// Versión para modo oscuro de un color de categoría: un poco más clara y menos saturada.
    var adaptadoAOscuro: UIColor {
        var tono: CGFloat = 0, saturacion: CGFloat = 0, brillo: CGFloat = 0, alfa: CGFloat = 0
        guard getHue(&tono, saturation: &saturacion, brightness: &brillo, alpha: &alfa) else { return self }
        return UIColor(
            hue: tono,
            saturation: saturacion * 0.88,
            brightness: min(1, brillo + (1 - brillo) * 0.35 + 0.04),
            alpha: alfa
        )
    }
}

extension Color {
    /// Color guardado como hex (categorías, cajitas). En modo oscuro se aclara solo,
    /// sin tocar el hex guardado.
    init(hex: String) {
        self.init(hex: hex, adaptar: true)
    }

    init(hex: String, adaptar: Bool) {
        let base = UIColor(hex: hex)
        if adaptar {
            let oscuro = base.adaptadoAOscuro
            self.init(uiColor: UIColor { trait in trait.userInterfaceStyle == .dark ? oscuro : base })
        } else {
            self.init(uiColor: base)
        }
    }

    /// Colores en rotación para las categorías que cree el usuario.
    static let coloresNuevos = ["0e7490", "be185d", "4d7c0f", "6d28d9", "c2410c", "0f766e", "a21caf"]
}

// MARK: Tarjeta

/// Tarjeta: superficie sin borde, sombra suave en claro y filo de luz en oscuro.
struct Panel: ViewModifier {
    var padding: CGFloat = Espacio.m
    var radio: CGFloat = Radio.tarjeta

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FondoTarjeta(radio: radio))
    }
}

/// Dentro de un `List` cada fila recorta lo que se sale de sus bordes, así que la sombra
/// suave de las tarjetas se vería como un rectángulo gris cortado. Las pantallas con `List`
/// la apagan con `.environment(\.tarjetasSinSombra, true)`.
private struct TarjetasSinSombraKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var tarjetasSinSombra: Bool {
        get { self[TarjetasSinSombraKey.self] }
        set { self[TarjetasSinSombraKey.self] = newValue }
    }
}

/// Fondo de tarjeta reutilizable (por ejemplo, detrás de un `VStack` de filas).
struct FondoTarjeta: View {
    var radio: CGFloat = Radio.tarjeta
    var color: Color = Theme.superficie
    @Environment(\.tarjetasSinSombra) private var sinSombra

    var body: some View {
        RoundedRectangle(cornerRadius: radio, style: .continuous)
            .fill(color)
            .shadow(color: Theme.sombraCercana, radius: 1, x: 0, y: 0.5)
            .shadow(color: sinSombra ? .clear : Theme.sombra, radius: 12, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: radio, style: .continuous)
                    .strokeBorder(Theme.bordeTarjeta, lineWidth: 0.5)
            )
    }
}

extension View {
    /// Tarjeta estándar. `padding: 0` para grupos de filas que traen su propio relleno.
    func panel(padding: CGFloat = Espacio.m) -> some View {
        modifier(Panel(padding: padding))
    }

    /// Ancho máximo de una columna (iPad / horizontal).
    func columna() -> some View {
        frame(maxWidth: 576)
    }

    /// Contenido de una pantalla con scroll: columna centrada con márgenes de 20.
    func contenidoPantalla() -> some View {
        self
            .columna()
            .padding(.horizontal, Espacio.margen)
            .padding(.top, Espacio.xs)
            .padding(.bottom, Espacio.xl)
            .frame(maxWidth: .infinity)
    }

    /// Fondo de pantalla que llega hasta los bordes.
    func fondoPantalla() -> some View {
        background(Theme.fondo.ignoresSafeArea())
    }
}
