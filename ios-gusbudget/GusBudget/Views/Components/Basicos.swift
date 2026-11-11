import SwiftUI
import UIKit

// MARK: - Ícono de categoría

/// Ícono SF Symbol dentro de un cuadro suave de su color. Decorativo: VoiceOver lo ignora.
struct IconoCuadro: View {
    let simbolo: String
    let color: Color
    var lado: CGFloat = 40
    /// Relleno sólido (por ejemplo, categoría seleccionada).
    var relleno: Bool = false

    @Environment(\.colorScheme) private var esquema
    @ScaledMetric(relativeTo: .body) private var escala: CGFloat = 1

    private var ladoFinal: CGFloat { lado * min(max(escala, 1), 1.35) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: ladoFinal * 0.28, style: .continuous)
                .fill(relleno ? color : color.opacity(esquema == .dark ? 0.22 : 0.14))
            Image(systemName: simbolo)
                .font(.system(size: ladoFinal * 0.45, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(relleno ? Color.white : color)
        }
        .frame(width: ladoFinal, height: ladoFinal)
        .accessibilityHidden(true)
    }
}

// MARK: - Navegador de mes

/// Navegador de mes: ‹ Noviembre 2026 ›. `compacto` para la barra de navegación (principal).
struct MesNavegador: View {
    @Binding var mes: Date
    var compacto: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        HStack(spacing: compacto ? 2 : Espacio.xs) {
            flecha("chevron.left", etiqueta: "Mes anterior", delta: -1)
            if !compacto { Spacer(minLength: 0) }
            Text(Fmt.mes(mes))
                .font(compacto ? .headline : .title3.weight(.semibold))
                .foregroundStyle(Theme.texto)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Mes: \(Fmt.mes(mes))")
            if !compacto { Spacer(minLength: 0) }
            flecha("chevron.right", etiqueta: "Mes siguiente", delta: 1)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { valor in
                    guard abs(valor.translation.width) > abs(valor.translation.height) else { return }
                    cambiar(valor.translation.width < 0 ? 1 : -1)
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityAdjustableAction { direccion in
            switch direccion {
            case .increment: cambiar(1)
            case .decrement: cambiar(-1)
            @unknown default: break
            }
        }
    }

    private func flecha(_ simbolo: String, etiqueta: String, delta: Int) -> some View {
        Button {
            cambiar(delta)
        } label: {
            Image(systemName: simbolo)
                .font(.system(size: compacto ? 14 : 15, weight: .semibold))
                .foregroundStyle(Theme.acento)
                .frame(width: compacto ? 32 : 36, height: compacto ? 32 : 36)
                .background(Circle().fill(compacto ? Color.clear : Theme.hundido))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(etiqueta)
    }

    private func cambiar(_ delta: Int) {
        Haptics.seleccion()
        withAnimation(reducirMovimiento ? nil : .spring(response: 0.35, dampingFraction: 0.85)) {
            mes = mes.sumandoMeses(delta)
        }
    }
}

// MARK: - Mosaico (dato pequeño)

/// Dato pequeño: título arriba y cifra abajo. `sobreOscuro` dentro de la tarjeta hero.
struct Mosaico: View {
    let titulo: String
    let valor: String
    var color: Color = Theme.texto
    var sobreOscuro: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.xxs) {
            Text(titulo)
                .font(.footnote)
                .foregroundStyle(sobreOscuro ? Color.white.opacity(0.72) : Theme.gris)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(valor)
                .font(.cifraMedia)
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Espacio.s)
        .padding(.horizontal, Espacio.s)
        .background(
            RoundedRectangle(cornerRadius: Radio.mosaico, style: .continuous)
                .fill(sobreOscuro ? Color.white.opacity(0.08) : Theme.hundido)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Barra de avance

/// Barra de avance en cápsula sobre una pista. Usa `Theme.colorAvance(_:)` para el color por estado.
struct BarraProgreso: View {
    let avance: Double
    var color: Color = Theme.acento
    var alto: CGFloat = 10
    /// Texto para VoiceOver; por defecto el porcentaje.
    var etiqueta: String?

    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.pista)
                Capsule()
                    .fill(color)
                    .frame(width: avance <= 0 ? 0 : max(alto, proxy.size.width * min(avance, 1)))
            }
        }
        .frame(height: alto)
        .animation(reducirMovimiento ? nil : .spring(response: 0.45, dampingFraction: 0.85), value: avance)
        .accessibilityElement()
        .accessibilityLabel(etiqueta ?? "Avance")
        .accessibilityValue(Fmt.porcentaje(max(avance, 0)))
    }
}

// MARK: - Campo de plata

/// Campo de plata con separadores de miles.
struct CampoPlata: View {
    @Binding var texto: String
    var marcador: String = "0"
    /// Estilo grande y centrado para hojas de registro.
    var grande: Bool = false
    var alineacion: TextAlignment = .leading
    /// Etiqueta para VoiceOver.
    var etiqueta: String = "Valor en pesos"
    /// Abre el teclado al aparecer (útil en hojas).
    var enfocarAlAparecer: Bool = false

    @FocusState private var enfocado: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var tamGrande: CGFloat = 48

    /// Tamaño del campo grande: con tope (para letra muy grande) y más chico con cifras largas,
    /// así un valor de 9-10 dígitos nunca se sale de la hoja en un iPhone pequeño.
    private var tamCampo: CGFloat {
        let base = min(tamGrande, 56)
        switch texto.count {
        case ..<10: return base
        case 10..<12: return base * 0.8
        default: return base * 0.65
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: grande ? 4 : 6) {
            if alineacion != .leading { Spacer(minLength: 0) }
            Text("$")
                .font(grande
                      ? .system(size: tamCampo * 0.6, weight: .semibold, design: .rounded)
                      : .body)
                .foregroundStyle(grande ? Theme.grisClaro : Theme.gris)
                .accessibilityHidden(true)
            TextField(marcador, text: $texto)
                .font(grande
                      ? .system(size: tamCampo, weight: .bold, design: .rounded)
                      : .system(.body, design: .rounded).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(Theme.texto)
                .keyboardType(.numberPad)
                .multilineTextAlignment(alineacion)
                .fixedSize(horizontal: alineacion == .center, vertical: false)
                .lineLimit(1)
                .focused($enfocado)
                .accessibilityLabel(etiqueta)
                .onChange(of: texto) { nuevo in
                    let soloNumeros = nuevo.filter { $0.isNumber }
                    if soloNumeros.isEmpty {
                        if !nuevo.isEmpty { texto = "" }
                        return
                    }
                    if let valor = Decimal(string: soloNumeros, locale: Locale(identifier: "en_US_POSIX")) {
                        let formateado = Fmt.numero(valor)
                        if formateado != nuevo { texto = formateado }
                    }
                }
            if alineacion == .center { Spacer(minLength: 0) }
        }
        .contentShape(Rectangle())
        .onTapGesture { enfocado = true }
        .onAppear {
            guard enfocarAlAparecer else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { enfocado = true }
        }
    }

    var valor: Decimal? { Fmt.leerPlata(texto) }
}

// MARK: - Cifra de plata

/// Cifra en pesos con números redondeados y de ancho fijo. El "$" va más tenue.
///
///     CifraPlata(valor: 18_000, estilo: .normal, signo: .salida)   // −$ 18.000
///     CifraPlata(valor: resultado.disponible, estilo: .hero)
struct CifraPlata: View {
    enum Estilo {
        /// 48 pt: la cifra protagonista de una pantalla (una sola).
        case hero
        /// 28 pt: cifra secundaria destacada.
        case titular
        /// title3: datos y KPIs.
        case media
        /// body: filas de lista.
        case normal
        /// subheadline: notas con plata.
        case pequena
    }

    enum Signo {
        /// Sin signo (valor absoluto si es negativo y `automatico` no aplica).
        case ninguno
        /// "+" en verde: plata que entra.
        case entrada
        /// "−" en color de texto: plata que sale (no es un error, no va en rojo).
        case salida
        /// Negativo con "−" en rojo; positivo sin signo.
        case automatico
    }

    let valor: Decimal
    var estilo: Estilo = .normal
    var signo: Signo = .automatico
    /// Fuerza el color (por ejemplo `.white` sobre la tarjeta hero).
    var color: Color?
    /// Cuánto puede encogerse antes de cortar (por defecto 0.6 en hero, 0.8 en el resto).
    var escalaMinima: CGFloat?

    @ScaledMetric(relativeTo: .largeTitle) private var tamHero: CGFloat = 48
    @ScaledMetric(relativeTo: .title) private var tamTitular: CGFloat = 28

    private var fuente: Font {
        switch estilo {
        case .hero: return .system(size: tamHero, weight: .bold, design: .rounded)
        case .titular: return .system(size: tamTitular, weight: .bold, design: .rounded)
        case .media: return .cifraMedia
        case .normal: return .cifra
        case .pequena: return .cifraPequena
        }
    }

    private var fuenteSimbolo: Font {
        switch estilo {
        case .hero: return .system(size: tamHero * 0.58, weight: .semibold, design: .rounded)
        case .titular: return .system(size: tamTitular * 0.7, weight: .semibold, design: .rounded)
        default: return fuente
        }
    }

    private var prefijo: String {
        switch signo {
        case .entrada: return "+"
        case .salida: return "−"
        case .automatico: return valor.redondeado < 0 ? "−" : ""
        case .ninguno: return ""
        }
    }

    private var colorFinal: Color {
        if let color { return color }
        switch signo {
        case .entrada: return Theme.verde
        case .automatico: return valor.redondeado < 0 ? Theme.rojo : Theme.texto
        default: return Theme.texto
        }
    }

    var body: some View {
        (Text(prefijo).font(fuente)
         + Text("$\u{00A0}").font(fuenteSimbolo).foregroundColor(colorFinal.opacity(0.62))
         + Text(Fmt.numero(abs(valor))).font(fuente))
            .monospacedDigit()
            .foregroundColor(colorFinal)
            .lineLimit(1)
            .minimumScaleFactor(escalaMinima ?? (estilo == .hero ? 0.6 : 0.8))
            .contentTransition(.numericText())
            .accessibilityLabel(CifraPlata.textoAccesible(valor, signo: signo))
    }

    /// "menos 18.000 pesos", "más 2.000.000 pesos".
    static func textoAccesible(_ valor: Decimal, signo: Signo = .automatico) -> String {
        let numero = "\(Fmt.numero(abs(valor))) pesos"
        switch signo {
        case .entrada: return "más \(numero)"
        case .salida: return "menos \(numero)"
        case .automatico: return valor.redondeado < 0 ? "menos \(numero)" : numero
        case .ninguno: return numero
        }
    }
}

// MARK: - Insignia

/// Tono semántico compartido por insignias, avisos y botones.
enum Tono {
    case neutro, tinte, positivo, aviso, negativo, sol

    var color: Color {
        switch self {
        case .neutro: return Theme.gris
        case .tinte: return Theme.acento
        case .positivo: return Theme.verde
        case .aviso: return Theme.ambar
        case .negativo: return Theme.rojo
        case .sol: return Theme.sobreSol
        }
    }

    var suave: Color {
        switch self {
        case .neutro: return Theme.hundido
        case .tinte: return Theme.acentoSuave
        case .positivo: return Theme.verdeSuave
        case .aviso: return Theme.ambarSuave
        case .negativo: return Theme.rojoSuave
        case .sol: return Theme.sol
        }
    }
}

/// Pastilla de estado: "Vencido", "Pronto", "Pagado".
struct Insignia: View {
    let texto: String
    var tono: Tono = .neutro
    var simbolo: String?

    var body: some View {
        HStack(spacing: 3) {
            if let simbolo {
                Image(systemName: simbolo).imageScale(.small)
            }
            Text(texto)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tono.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(tono.suave))
        .lineLimit(1)
        .fixedSize()
    }
}

// MARK: - Chip

/// Chip seleccionable de 36 pt (área táctil de 44 pt) para filtros y sugerencias.
struct Chip: View {
    let titulo: String
    var simbolo: String?
    var seleccionado: Bool = false
    var accion: () -> Void

    var body: some View {
        Button {
            Haptics.seleccion()
            accion()
        } label: {
            HStack(spacing: 6) {
                if let simbolo {
                    Image(systemName: simbolo).imageScale(.small)
                }
                Text(titulo).lineLimit(1)
            }
            .font(.subheadline.weight(seleccionado ? .semibold : .medium))
            .foregroundStyle(seleccionado ? Theme.sobreAcento : Theme.texto)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(Capsule().fill(seleccionado ? Theme.acento : Theme.hundido))
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.presionable)
        .accessibilityAddTraits(seleccionado ? .isSelected : [])
    }
}

// MARK: - Toast

/// Mensaje corto que aparece abajo por unos segundos, con acción opcional ("Deshacer").
struct Toast: View {
    let texto: String
    var accionTitulo: String?
    var accion: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(hex: "4ED19A", adaptar: false))
                .accessibilityHidden(true)
            Text(texto)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            if let accionTitulo, let accion {
                Spacer(minLength: 4)
                Button(accionTitulo, action: accion)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(hex: "FFC247", adaptar: false))
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, accionTitulo == nil ? 18 : 14)
        .frame(minHeight: 48)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: "161D3C", adaptar: false))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Vacío

/// "No hay nada todavía" dentro de una tarjeta. Para una pantalla o sección vacía con acción, usa `EstadoVacio`.
struct Vacio: View {
    let simbolo: String
    let texto: String

    var body: some View {
        VStack(spacing: Espacio.s) {
            Image(systemName: simbolo)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Theme.gris)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Theme.hundido))
                .accessibilityHidden(true)
            Text(texto)
                .font(.subheadline)
                .foregroundStyle(Theme.gris)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Espacio.xl)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Título dentro de tarjeta

/// Título DENTRO de una tarjeta. Para títulos de sección fuera de tarjetas usa `EncabezadoSeccion`.
struct TituloSeccion: View {
    let texto: String
    var detalle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(texto)
                .font(.headline)
                .foregroundStyle(Theme.texto)
            if let detalle {
                Text(detalle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.gris)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Encabezado de sección (fuera de tarjetas)

/// Título de sección encima de una tarjeta o grupo, con enlace opcional a la derecha ("Ver todo").
struct EncabezadoSeccion: View {
    let titulo: String
    var detalle: String?
    var accionTitulo: String?
    var accion: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Espacio.xs) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.texto)
                    .accessibilityAddTraits(.isHeader)
                if let detalle {
                    Text(detalle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.gris)
                }
            }
            Spacer(minLength: Espacio.xs)
            if let accionTitulo, let accion {
                Button(accionTitulo, action: accion)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.acento)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, Espacio.xxs)
    }
}

/// Sobrelínea de grupo en mayúsculas ("VENCIDOS", "ESTA SEMANA"), opcionalmente con color de estado.
struct Sobrelinea: View {
    let texto: String
    var color: Color = Theme.gris

    var body: some View {
        Text(texto)
            .font(.sobrelinea)
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(color)
            .padding(.horizontal, Espacio.xxs)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Separador de filas

/// Separador fino entre filas de un grupo; la sangría alinea con el texto (después del ícono).
struct SeparadorFila: View {
    var sangria: CGFloat = 68

    var body: some View {
        Rectangle()
            .fill(Theme.linea)
            .frame(height: 0.5)
            .padding(.leading, sangria)
    }
}

// MARK: - Hápticos extra

extension Haptics {
    /// Toque de selección (chips, categorías, cambio de mes).
    static func seleccion() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
