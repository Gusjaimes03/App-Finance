import SwiftUI

// MARK: - Fondo hero

/// Fondo de marca: degradado azul noche con un resplandor tenue de sol arriba a la derecha.
struct FondoHero: View {
    var radio: CGFloat = Radio.hero
    @Environment(\.tarjetasSinSombra) private var sinSombra

    var body: some View {
        RoundedRectangle(cornerRadius: radio, style: .continuous)
            .fill(Theme.heroGradient)
            .overlay(
                RadialGradient(
                    colors: [Theme.sol.opacity(0.16), Theme.sol.opacity(0)],
                    center: UnitPoint(x: 0.95, y: -0.05),
                    startRadius: 4,
                    endRadius: 260
                )
                .clipShape(RoundedRectangle(cornerRadius: radio, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radio, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.02)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
            )
            .shadow(color: sinSombra ? .clear
                        : Theme.dynamic(light: "0C1433", lightAlpha: 0.28, dark: "000000", darkAlpha: 0),
                    radius: 24, x: 0, y: 12)
    }
}

// MARK: - Tarjeta hero

/// La tarjeta protagonista de una pantalla (una sola por pantalla). Su contenido se dibuja en
/// esquema oscuro, así que `Theme.texto`, `Theme.gris`, `Insignia`, etc. se ven bien solos.
///
///     TarjetaHero {
///         Text("Hoy puedes gastar").font(.subheadline.weight(.medium)).foregroundStyle(Theme.gris)
///         CifraPlata(valor: 54_000, estilo: .hero, color: .white)
///         Text("Hasta el 15 · quedan 6 días").font(.subheadline).foregroundStyle(Theme.gris)
///         ResumenDatos(datos: [...], sobreOscuro: true)
///     }
struct TarjetaHero<Contenido: View>: View {
    var espaciado: CGFloat = Espacio.s
    @ViewBuilder var contenido: () -> Contenido

    var body: some View {
        VStack(alignment: .leading, spacing: espaciado) {
            contenido()
        }
        .environment(\.colorScheme, .dark)
        .padding(Espacio.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FondoHero())
    }
}

// MARK: - Resumen de datos

/// Un dato de `ResumenDatos`.
struct DatoResumen: Identifiable {
    var id: String { titulo }
    let titulo: String
    let valor: Decimal
    var signo: CifraPlata.Signo = .automatico
    var color: Color?
}

/// Fila de 2 o 3 datos separados por líneas verticales (reemplaza a los mosaicos apretados).
/// En tamaños de letra de accesibilidad se apila en vertical.
struct ResumenDatos: View {
    let datos: [DatoResumen]
    /// Dentro de la tarjeta hero: separadores y textos claros.
    var sobreOscuro: Bool = false

    @Environment(\.dynamicTypeSize) private var tamano

    var body: some View {
        if tamano.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Espacio.s) {
                ForEach(datos) { celda($0) }
            }
        } else {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(datos.enumerated()), id: \.element.id) { indice, dato in
                    if indice > 0 {
                        Rectangle()
                            .fill(sobreOscuro ? Color.white.opacity(0.14) : Theme.linea)
                            .frame(width: 0.5)
                            .padding(.horizontal, Espacio.s)
                    }
                    celda(dato)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func celda(_ dato: DatoResumen) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(dato.titulo)
                .font(.footnote)
                .foregroundStyle(sobreOscuro ? Color.white.opacity(0.7) : Theme.gris)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            CifraPlata(valor: dato.valor, estilo: .media, signo: dato.signo,
                       color: dato.color ?? (sobreOscuro && dato.valor >= 0 ? .white : nil),
                       escalaMinima: datos.count > 2 ? 0.6 : 0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Fila de lista

/// Fila estándar: ícono, título y subtítulo a la izquierda y lo que quieras a la derecha.
/// Mínimo 60 pt de alto. Para meterla en una tarjeta: `VStack(spacing: 0) { fila; SeparadorFila(); fila }.panel(padding: 0)`.
///
///     FilaLista(simbolo: cat.simbolo, color: cat.color, titulo: "Almuerzo", subtitulo: "Comida · 12:30") {
///         CifraPlata(valor: 18_000, signo: .salida)
///     }
struct FilaLista<Derecha: View>: View {
    let simbolo: String
    let color: Color
    let titulo: String
    var subtitulo: String?
    var insignia: Insignia?
    @ViewBuilder var derecha: () -> Derecha

    var body: some View {
        HStack(spacing: Espacio.s) {
            IconoCuadro(simbolo: simbolo, color: color, lado: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(titulo)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.texto)
                        .lineLimit(2)
                    if let insignia { insignia }
                }
                if let subtitulo, !subtitulo.isEmpty {
                    Text(subtitulo)
                        .font(.subheadline)
                        .foregroundStyle(Theme.gris)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            derecha()
        }
        .padding(.vertical, Espacio.s)
        .padding(.horizontal, Espacio.m)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
    }
}

extension FilaLista where Derecha == CifraPlata {
    /// Fila con una cifra a la derecha.
    init(simbolo: String, color: Color, titulo: String, subtitulo: String? = nil,
         insignia: Insignia? = nil, valor: Decimal, signo: CifraPlata.Signo = .automatico) {
        self.init(simbolo: simbolo, color: color, titulo: titulo, subtitulo: subtitulo, insignia: insignia) {
            CifraPlata(valor: valor, estilo: .normal, signo: signo)
        }
    }
}

// MARK: - Aviso

/// Aviso compacto con fondo suave del tono. Si tiene `accion`, toda la tarjeta es tocable.
///
///     BannerAviso(simbolo: "exclamationmark.triangle.fill", titulo: "Comida va en 92 %",
///                 mensaje: "+2 avisos más", tono: .aviso) { pestana = .presupuesto }
struct BannerAviso: View {
    var simbolo: String = "exclamationmark.triangle.fill"
    let titulo: String
    var mensaje: String?
    var tono: Tono = .aviso
    var accion: (() -> Void)?

    var body: some View {
        if let accion {
            Button(action: accion) { contenido }
                .buttonStyle(.presionable)
        } else {
            contenido
        }
    }

    private var contenido: some View {
        HStack(alignment: .top, spacing: Espacio.s) {
            Image(systemName: simbolo)
                .font(.body.weight(.semibold))
                .foregroundStyle(tono.color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.texto)
                    .fixedSize(horizontal: false, vertical: true)
                if let mensaje {
                    Text(mensaje)
                        .font(.footnote)
                        .foregroundStyle(Theme.gris)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if accion != nil {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.grisClaro)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, Espacio.s)
        .padding(.horizontal, Espacio.m)
        .frame(minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: Radio.mosaico + 2, style: .continuous)
                .fill(tono.suave)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Estado vacío

/// Estado vacío con llamado a la acción: "Registra tu primer gasto".
struct EstadoVacio: View {
    let simbolo: String
    let titulo: String
    var mensaje: String?
    var accionTitulo: String?
    var accion: (() -> Void)?

    var body: some View {
        VStack(spacing: Espacio.s) {
            Image(systemName: simbolo)
                .font(.system(size: 24, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.acento)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Theme.acentoSuave))
                .accessibilityHidden(true)
            Text(titulo)
                .font(.headline)
                .foregroundStyle(Theme.texto)
                .multilineTextAlignment(.center)
            if let mensaje {
                Text(mensaje)
                    .font(.subheadline)
                    .foregroundStyle(Theme.gris)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let accionTitulo, let accion {
                Button(accionTitulo, action: accion)
                    .buttonStyle(.secundario)
                    .padding(.top, Espacio.xxs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Espacio.xl)
        .padding(.horizontal, Espacio.m)
    }
}

// MARK: - Mosaico de categoría

/// Opción de una cuadrícula de categorías (registrar / corregir gasto). Se llena al seleccionarla.
///
///     LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
///         ForEach(store.categoriasVisibles) { c in
///             MosaicoCategoria(simbolo: c.simbolo, color: c.color, nombre: c.nombre,
///                              seleccionado: c.id == categoriaID) { categoriaID = c.id }
///         }
///     }
struct MosaicoCategoria: View {
    let simbolo: String
    let color: Color
    let nombre: String
    var seleccionado: Bool = false
    var accion: () -> Void

    @ScaledMetric(relativeTo: .footnote) private var alto: CGFloat = 92
    /// Alto de dos líneas de texto, para que todas las opciones midan igual.
    @ScaledMetric(relativeTo: .footnote) private var altoTexto: CGFloat = 34

    var body: some View {
        Button {
            Haptics.seleccion()
            accion()
        } label: {
            VStack(spacing: Espacio.xs) {
                IconoCuadro(simbolo: simbolo, color: color, lado: 40, relleno: seleccionado)
                Text(nombre)
                    .font(.footnote.weight(seleccionado ? .semibold : .regular))
                    .foregroundStyle(Theme.texto)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .frame(maxWidth: .infinity, minHeight: altoTexto, alignment: .top)
            }
            .padding(.horizontal, 6)
            .padding(.top, Espacio.s)
            .padding(.bottom, Espacio.xs)
            .frame(maxWidth: .infinity, minHeight: alto, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: Radio.mosaico, style: .continuous)
                    .fill(seleccionado ? color.opacity(0.12) : Theme.hundido)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radio.mosaico, style: .continuous)
                    .strokeBorder(seleccionado ? color : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.presionable)
        .accessibilityLabel(nombre)
        .accessibilityAddTraits(seleccionado ? .isSelected : [])
    }
}
