import SwiftUI

// MARK: - Botón principal

/// Botón principal: cápsula de 52 pt a todo el ancho, `.headline`. Uno por pantalla u hoja.
///
///     Button("Guardar gasto") { … }.buttonStyle(.principal)
///     Button("Ya me llegó") { … }.buttonStyle(.principal(Theme.verde))
struct EstiloBotonPrincipal: ButtonStyle {
    var color: Color = Theme.acento
    var colorTexto: Color = Theme.sobreAcento
    var anchoCompleto: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        CuerpoPrincipal(configuration: configuration, color: color, colorTexto: colorTexto, anchoCompleto: anchoCompleto)
    }

    private struct CuerpoPrincipal: View {
        let configuration: ButtonStyleConfiguration
        let color: Color
        let colorTexto: Color
        let anchoCompleto: Bool
        @Environment(\.isEnabled) private var activo

        var body: some View {
            configuration.label
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundStyle(activo ? colorTexto : Theme.grisClaro)
                .padding(.horizontal, Espacio.xl)
                .frame(maxWidth: anchoCompleto ? .infinity : nil, minHeight: 52)
                .background(
                    Capsule(style: .continuous)
                        .fill(activo ? color : Theme.hundido)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .opacity(configuration.isPressed ? 0.88 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
                .contentShape(Capsule())
        }
    }
}

// MARK: - Botón secundario

/// Botón secundario: cápsula con relleno tenue del color (12 %), mínimo 44 pt de alto.
///
///     Button("Guardar plata") { … }.buttonStyle(.secundario)
///     Button("Borrar") { … }.buttonStyle(.secundario(Theme.rojo))
struct EstiloBotonSecundario: ButtonStyle {
    var color: Color = Theme.acento
    var anchoCompleto: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        CuerpoSecundario(configuration: configuration, color: color, anchoCompleto: anchoCompleto)
    }

    private struct CuerpoSecundario: View {
        let configuration: ButtonStyleConfiguration
        let color: Color
        let anchoCompleto: Bool
        @Environment(\.isEnabled) private var activo
        @Environment(\.colorScheme) private var esquema

        var body: some View {
            configuration.label
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundStyle(activo ? color : Theme.grisClaro)
                .padding(.horizontal, Espacio.m)
                .frame(maxWidth: anchoCompleto ? .infinity : nil, minHeight: 44)
                .background(
                    Capsule(style: .continuous)
                        .fill(activo ? color.opacity(esquema == .dark ? 0.2 : 0.12) : Theme.hundido)
                )
                .opacity(configuration.isPressed ? 0.7 : 1)
                .contentShape(Capsule())
        }
    }
}

// MARK: - Presionable

/// Para filas y tarjetas tocables: se encoge un poco al presionar, sin cambiar colores.
struct EstiloPresionable: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == EstiloBotonPrincipal {
    static var principal: EstiloBotonPrincipal { EstiloBotonPrincipal() }
    static func principal(_ color: Color, texto: Color = .white) -> EstiloBotonPrincipal {
        EstiloBotonPrincipal(color: color, colorTexto: texto)
    }
}

extension ButtonStyle where Self == EstiloBotonSecundario {
    static var secundario: EstiloBotonSecundario { EstiloBotonSecundario() }
    static func secundario(_ color: Color, anchoCompleto: Bool = false) -> EstiloBotonSecundario {
        EstiloBotonSecundario(color: color, anchoCompleto: anchoCompleto)
    }
}

extension ButtonStyle where Self == EstiloPresionable {
    static var presionable: EstiloPresionable { EstiloPresionable() }
}

// MARK: - Botón de ícono

/// Botón redondo solo con ícono (44 × 44): "más opciones", "info", "+" en encabezados.
struct BotonIcono: View {
    let simbolo: String
    let etiqueta: String
    var color: Color = Theme.acento
    var relleno: Bool = true
    var accion: () -> Void

    var body: some View {
        Button(action: accion) {
            Image(systemName: simbolo)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(Circle().fill(relleno ? Theme.hundido : Color.clear))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.presionable)
        .accessibilityLabel(etiqueta)
    }
}

/// Menú "más opciones" (•••) de 44 × 44 para acciones secundarias de una fila o tarjeta.
///
///     MenuMas { Button("Sacar plata") { … }; Button("Borrar", role: .destructive) { … } }
struct MenuMas<Contenido: View>: View {
    var etiqueta: String = "Más opciones"
    @ViewBuilder var contenido: () -> Contenido

    var body: some View {
        Menu(content: contenido) {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.gris)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Theme.hundido))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(etiqueta)
    }
}

// MARK: - Check circular

/// Check circular para "Ya pagué" / "Ya me llegó": círculo con contorno que se llena al tocarlo.
/// Mide 44 × 44 de área táctil. `etiqueta` es lo que lee VoiceOver ("Ya pagué Arriendo").
struct BotonCheck: View {
    var hecho: Bool = false
    var color: Color = Theme.acento
    let etiqueta: String
    var accion: () -> Void

    @ScaledMetric(relativeTo: .body) private var lado: CGFloat = 20

    var body: some View {
        Button {
            Haptics.tap()
            accion()
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(hecho ? Color.clear : Theme.gris.opacity(0.35), lineWidth: 1.5)
                    .background(Circle().fill(hecho ? Theme.verde : Color.clear))
                if hecho {
                    Image(systemName: "checkmark")
                        .font(.system(size: lado * 0.5, weight: .bold))
                        .foregroundStyle(Color.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: lado, height: lado)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.presionable)
        .accessibilityLabel(etiqueta)
        .accessibilityAddTraits(hecho ? .isSelected : [])
    }
}

// MARK: - Botón flotante

/// Botón flotante "+" (60 pt) para registrar desde cualquier pestaña.
struct BotonFlotante: View {
    var simbolo: String = "plus"
    var etiqueta: String = "Registrar gasto o ingreso"
    var accion: () -> Void

    @ScaledMetric(relativeTo: .title) private var lado: CGFloat = 60

    var body: some View {
        Button {
            Haptics.tap()
            accion()
        } label: {
            Image(systemName: simbolo)
                .font(.system(size: min(lado, 72) * 0.4, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: min(lado, 72), height: min(lado, 72))
                .background(
                    Circle()
                        .fill(Theme.acentoFuerte)
                        .overlay(
                            Circle().fill(
                                LinearGradient(colors: [Color.white.opacity(0.18), .clear],
                                               startPoint: .top, endPoint: .center)
                            )
                        )
                )
                .shadow(color: Color.black.opacity(0.18), radius: 16, y: 6)
                .contentShape(Circle())
        }
        .buttonStyle(.presionable)
        .accessibilityLabel(etiqueta)
    }
}
