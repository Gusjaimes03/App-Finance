import SwiftUI

/// Ícono de categoría dentro de un cuadro de su color.
struct IconoCuadro: View {
    let simbolo: String
    let color: Color
    var lado: CGFloat = 38
    var relleno: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: lado * 0.3, style: .continuous)
                .fill(relleno ? color : color.opacity(0.15))
            Image(systemName: simbolo)
                .font(.system(size: lado * 0.42, weight: .semibold))
                .foregroundStyle(relleno ? Color.white : color)
        }
        .frame(width: lado, height: lado)
    }
}

/// Navegador de mes: ‹ Anterior · noviembre · Siguiente ›
struct MesNavegador: View {
    @Binding var mes: Date

    var body: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { mes = mes.sumandoMeses(-1) }
            } label: {
                Label("Anterior", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
                    .font(.headline)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mes anterior")

            Spacer(minLength: 0)
            Text(Fmt.mes(mes))
                .font(.headline)
                .foregroundStyle(Theme.texto)
            Spacer(minLength: 0)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) { mes = mes.sumandoMeses(1) }
            } label: {
                Label("Siguiente", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
                    .font(.headline)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mes siguiente")
        }
        .padding(.horizontal, 4)
    }
}

/// Mosaico pequeño con un título y una cifra.
struct Mosaico: View {
    let titulo: String
    let valor: String
    var color: Color = Theme.texto
    var sobreOscuro: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(titulo)
                .font(.caption2)
                .foregroundStyle(sobreOscuro ? Color.white.opacity(0.75) : Theme.gris)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(valor)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
        .padding(.horizontal, 11)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(sobreOscuro ? Color.white.opacity(0.12) : Theme.fondo)
        )
    }
}

/// Barra de avance con color propio.
struct BarraProgreso: View {
    let avance: Double
    var color: Color = Theme.acento
    var alto: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.linea)
                Capsule()
                    .fill(color)
                    .frame(width: max(4, proxy.size.width * min(max(avance, 0), 1)))
            }
        }
        .frame(height: alto)
    }
}

/// Campo de plata con separadores de miles.
struct CampoPlata: View {
    @Binding var texto: String
    var marcador: String = "0"
    var grande: Bool = false
    var alineacion: TextAlignment = .leading
    @FocusState private var enfocado: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text("$")
                .font(grande ? .system(size: 30, weight: .bold, design: .rounded) : .body)
                .foregroundStyle(Theme.gris)
            TextField(marcador, text: $texto)
                .font(grande ? .system(size: 40, weight: .bold, design: .rounded) : .body)
                .keyboardType(.numberPad)
                .multilineTextAlignment(alineacion)
                .focused($enfocado)
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
        }
    }

    var valor: Decimal? { Fmt.leerPlata(texto) }
}

/// Mensaje corto que aparece abajo por unos segundos.
struct Toast: View {
    let texto: String

    var body: some View {
        Text(texto)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                Capsule().fill(Theme.heroInicio.opacity(0.95))
            )
            .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// Texto de "no hay nada todavía".
struct Vacio: View {
    let simbolo: String
    let texto: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: simbolo)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Theme.gris)
            Text(texto)
                .font(.subheadline)
                .foregroundStyle(Theme.gris)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }
}

/// Encabezado de sección dentro de una tarjeta.
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
                    .font(.caption)
                    .foregroundStyle(Theme.gris)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
