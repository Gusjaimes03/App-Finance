import SwiftUI

/// Tramo de la dona.
struct TramoDona: Identifiable {
    let id: String
    let valor: Double
    let color: Color
    let nombre: String
}

// MARK: - Dona

/// Dona "En qué se fue tu plata": tramos con puntas redondas y pequeñas separaciones,
/// total al centro. `resaltado` atenúa los demás tramos.
struct Dona: View {
    let tramos: [TramoDona]
    let total: Decimal
    /// Grosor del trazo. Si es nil, 16 % del lado.
    var grosor: CGFloat? = nil
    var lado: CGFloat = 140
    var etiquetaCentro: String = "en el mes"
    var resaltado: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @State private var progreso: Double = 0

    private var trazo: CGFloat { grosor ?? max(12, lado * 0.16) }
    private var suma: Double { max(tramos.reduce(0) { $0 + max($1.valor, 0) }, 0.0001) }

    private struct Segmento: Identifiable {
        let id: String
        let color: Color
        let desde: Double
        let hasta: Double
        let redondo: Bool
    }

    private var segmentos: [Segmento] {
        let validos = tramos.filter { $0.valor > 0 }
        let circunferencia = Double.pi * Double(lado - trazo)
        let punta = Double(trazo / 2) / max(circunferencia, 1)
        let hueco = validos.count > 1 ? (1.5 / 360) : 0
        var cursor: Double = 0
        var lista: [Segmento] = []
        for tramo in validos {
            let parte = tramo.valor / suma
            let inicio = cursor + hueco / 2
            let fin = cursor + parte - hueco / 2
            // Con puntas redondas el trazo se alarga media punta por lado.
            if validos.count > 1, fin - inicio > punta * 2 + 0.002 {
                lista.append(Segmento(id: tramo.id, color: tramo.color,
                                      desde: inicio + punta, hasta: fin - punta, redondo: true))
            } else {
                lista.append(Segmento(id: tramo.id, color: tramo.color,
                                      desde: inicio, hasta: max(fin, inicio + 0.002),
                                      redondo: validos.count == 1))
            }
            cursor += parte
        }
        return lista
    }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.pista, lineWidth: trazo)
            ForEach(segmentos) { segmento in
                Circle()
                    .trim(from: segmento.desde * progreso, to: segmento.hasta * progreso)
                    .stroke(segmento.color,
                            style: StrokeStyle(lineWidth: trazo, lineCap: segmento.redondo ? .round : .butt))
                    .rotationEffect(.degrees(-90))
                    .opacity(resaltado == nil || resaltado == segmento.id ? 1 : 0.25)
            }
            VStack(spacing: 2) {
                Text(Fmt.plata(total))
                    .font(.cifraMedia)
                    .monospacedDigit()
                    .foregroundStyle(Theme.texto)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(etiquetaCentro)
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(Theme.gris)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(trazo + 8)
        }
        .frame(width: lado, height: lado)
        .animation(.easeInOut(duration: 0.25), value: resaltado)
        .animation(reducirMovimiento ? nil : .easeOut(duration: 0.3), value: tramos.map(\.valor))
        .onAppear {
            if reducirMovimiento {
                progreso = 1
            } else {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.9)) { progreso = 1 }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("En qué se fue tu plata")
        .accessibilityValue(Dona.resumenAccesible(tramos, total: total))
    }

    static func resumenAccesible(_ tramos: [TramoDona], total: Decimal) -> String {
        let partes = tramos.filter { $0.valor > 0 }.map { tramo -> String in
            let porcentaje = Fmt.porcentaje(total > 0 ? tramo.valor / total.doble : 0)
            return "\(tramo.nombre), \(Fmt.numero(Decimal(tramo.valor))) pesos, \(porcentaje)"
        }
        return (["Total \(Fmt.numero(total)) pesos"] + partes).joined(separator: ". ")
    }
}

// MARK: - Leyenda

/// Leyenda de la dona: color, nombre, valor y porcentaje. Tocar una fila resalta su tramo
/// si se pasa `resaltado`.
struct LeyendaDona: View {
    let tramos: [TramoDona]
    let total: Decimal
    var resaltado: Binding<String?>? = nil
    /// Dos líneas por fila (nombre arriba, valor y % abajo) para ir al lado de la dona.
    var compacta: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compacta ? 8 : 2) {
            ForEach(tramos) { tramo in
                fila(tramo)
            }
        }
    }

    @ViewBuilder
    private func fila(_ tramo: TramoDona) -> some View {
        let activa = resaltado?.wrappedValue
        let porcentaje = Fmt.porcentaje(total > 0 ? tramo.valor / total.doble : 0)
        let contenido = Group {
            if compacta {
                HStack(alignment: .firstTextBaseline, spacing: Espacio.xs) {
                    Circle().fill(tramo.color).frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tramo.nombre)
                            .font(.subheadline)
                            .foregroundStyle(Theme.texto)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text(Fmt.plata(Decimal(tramo.valor)))
                                .font(.cifraPequena)
                                .foregroundStyle(Theme.texto)
                            Text("· \(porcentaje)")
                                .font(.footnote)
                                .foregroundStyle(Theme.gris)
                        }
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: Espacio.xs) {
            Circle().fill(tramo.color).frame(width: 10, height: 10)
            Text(tramo.nombre)
                .font(.subheadline)
                .foregroundStyle(Theme.texto)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(Fmt.plata(Decimal(tramo.valor)))
                .font(.cifraPequena)
                .monospacedDigit()
                .foregroundStyle(Theme.texto)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(porcentaje)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(Theme.gris)
                .frame(minWidth: 40, alignment: .trailing)
                }
            }
        }
        .frame(minHeight: 32)
        .opacity(activa == nil || activa == tramo.id ? 1 : 0.45)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)

        if let resaltado {
            Button {
                Haptics.seleccion()
                resaltado.wrappedValue = resaltado.wrappedValue == tramo.id ? nil : tramo.id
            } label: { contenido }
                .buttonStyle(.plain)
                .accessibilityAddTraits(activa == tramo.id ? .isSelected : [])
        } else {
            contenido
        }
    }
}

/// Dona + leyenda con resaltado interactivo. Se apila en vertical con letra grande o poco ancho.
struct DonaConLeyenda: View {
    let tramos: [TramoDona]
    let total: Decimal
    var lado: CGFloat = 128
    var etiquetaCentro: String = "en el mes"

    @State private var resaltado: String?
    @Environment(\.dynamicTypeSize) private var tamano

    var body: some View {
        if tamano >= .xxLarge {
            VStack(spacing: Espacio.m) {
                dona
                LeyendaDona(tramos: tramos, total: total, resaltado: $resaltado)
            }
        } else {
            HStack(alignment: .center, spacing: Espacio.l) {
                dona
                LeyendaDona(tramos: tramos, total: total, resaltado: $resaltado, compacta: true)
            }
        }
    }

    private var dona: some View {
        Dona(tramos: tramos, total: total, lado: lado, etiquetaCentro: etiquetaCentro, resaltado: resaltado)
    }
}

// MARK: - Anillo de avance

/// Anillo de avance (cajitas, día a día). Contenido opcional al centro.
struct AnilloProgreso<Centro: View>: View {
    let avance: Double
    var color: Color = Theme.acento
    var lado: CGFloat = 56
    var grosor: CGFloat? = nil
    @ViewBuilder var centro: () -> Centro

    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    private var trazo: CGFloat { grosor ?? max(5, lado * 0.12) }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.pista, lineWidth: trazo)
            Circle()
                .trim(from: 0, to: min(max(avance, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: trazo, lineCap: .round))
                .rotationEffect(.degrees(-90))
            centro()
        }
        .frame(width: lado, height: lado)
        .animation(reducirMovimiento ? nil : .spring(response: 0.5, dampingFraction: 0.85), value: avance)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Avance")
        .accessibilityValue(Fmt.porcentaje(max(avance, 0)))
    }
}

extension AnilloProgreso where Centro == EmptyView {
    init(avance: Double, color: Color = Theme.acento, lado: CGFloat = 56, grosor: CGFloat? = nil) {
        self.init(avance: avance, color: color, lado: lado, grosor: grosor) { EmptyView() }
    }
}

extension AnilloProgreso where Centro == AnyView {
    /// Anillo con el porcentaje al centro.
    init(conPorcentaje avance: Double, color: Color = Theme.acento, lado: CGFloat = 56) {
        self.init(avance: avance, color: color, lado: lado, grosor: nil) {
            AnyView(
                Text(Fmt.porcentaje(max(avance, 0)))
                    .font(.system(size: lado * 0.24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.texto)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(lado * 0.14)
            )
        }
    }
}

// MARK: - Barras por día

/// Barras por día del mes con la línea punteada del presupuesto diario.
/// Tocar una barra muestra el valor de ese día.
struct BarrasPorDia: View {
    let dias: [TotalDia]
    let presupuestoDiario: Decimal
    var alto: CGFloat = 140

    @State private var seleccion: Date?
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    private var maximo: Double {
        max(dias.map { $0.total.doble }.max() ?? 0, presupuestoDiario.doble * 1.15, 1)
    }

    private var marcasEje: Set<Int> {
        guard !dias.isEmpty else { return [] }
        return [1, 8, 15, 22, dias.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                let ancho = proxy.size.width
                let espacio: CGFloat = dias.count > 20 ? 3 : 4
                let anchoBarra = max(2, (ancho - espacio * CGFloat(max(dias.count - 1, 0))) / CGFloat(max(dias.count, 1)))

                ZStack(alignment: .bottomLeading) {
                    HStack(alignment: .bottom, spacing: espacio) {
                        ForEach(dias) { dia in
                            let valor = dia.total.doble
                            let altura = valor == 0 ? 3 : max(anchoBarra, proxy.size.height * valor / maximo)
                            UnevenCapsula(radio: min(anchoBarra / 2, 6))
                                .fill(color(dia: dia, valor: valor))
                                .frame(height: altura)
                                .opacity(seleccion == nil || seleccion == dia.fecha ? 1 : 0.4)
                        }
                    }

                    if presupuestoDiario > 0 {
                        let y = proxy.size.height * (1 - presupuestoDiario.doble / maximo)
                        Path { camino in
                            camino.move(to: CGPoint(x: 0, y: y))
                            camino.addLine(to: CGPoint(x: ancho, y: y))
                        }
                        .stroke(Theme.grisClaro, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                        Text("Diario \(Fmt.plata(presupuestoDiario))")
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.gris)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.hundido))
                            .position(x: ancho - 58, y: max(9, y - 11))
                            .allowsHitTesting(false)
                    }

                    if let seleccion, let indice = dias.firstIndex(where: { $0.fecha == seleccion }) {
                        let dia = dias[indice]
                        let x = CGFloat(indice) * (anchoBarra + espacio) + anchoBarra / 2
                        VStack(spacing: 1) {
                            Text(Fmt.fechaCorta(dia.fecha))
                                .font(.caption2)
                                .foregroundStyle(Theme.gris)
                            Text(Fmt.plata(dia.total))
                                .font(.cifraPequena)
                                .monospacedDigit()
                                .foregroundStyle(Theme.texto)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(FondoTarjeta(radio: 12, color: Theme.elevada))
                        .fixedSize()
                        .position(x: min(max(x, 56), ancho - 56), y: 20)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture().onEnded { evento in
                        let indice = Int(evento.location.x / (anchoBarra + espacio))
                        guard dias.indices.contains(indice) else { return }
                        Haptics.seleccion()
                        let fecha = dias[indice].fecha
                        withAnimation(reducirMovimiento ? nil : .easeOut(duration: 0.15)) {
                            seleccion = seleccion == fecha ? nil : fecha
                        }
                    }
                )
            }
            .frame(height: alto)

            HStack(spacing: dias.count > 20 ? 3 : 4) {
                ForEach(Array(dias.enumerated()), id: \.element.id) { indice, _ in
                    Color.clear
                        .frame(height: 14)
                        .overlay(
                            Group {
                                if marcasEje.contains(indice + 1) {
                                    Text("\(indice + 1)")
                                        .font(.caption2)
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.grisClaro)
                                        .fixedSize()
                                }
                            }
                        )
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Gasto por día")
        .accessibilityValue(resumenAccesible)
    }

    private var resumenAccesible: String {
        let total = dias.reduce(Decimal.zero) { $0 + $1.total }
        var partes = ["Total del mes \(Fmt.numero(total)) pesos"]
        if presupuestoDiario > 0 {
            let encima = dias.filter { $0.total > presupuestoDiario }.count
            partes.append("Presupuesto diario \(Fmt.numero(presupuestoDiario)) pesos")
            partes.append(encima == 1 ? "1 día por encima" : "\(encima) días por encima")
        }
        if let mayor = dias.max(by: { $0.total < $1.total }), mayor.total > 0 {
            partes.append("Día con más gasto: \(Fmt.fechaCorta(mayor.fecha)), \(Fmt.numero(mayor.total)) pesos")
        }
        return partes.joined(separator: ". ")
    }

    private func color(dia: TotalDia, valor: Double) -> Color {
        if Calendar.app.isDateInToday(dia.fecha) { return Theme.sol }
        if valor == 0 { return Theme.pista }
        if presupuestoDiario > 0 && valor > presupuestoDiario.doble { return Theme.rojo }
        return Theme.acento
    }
}

/// Barra con la parte de arriba redondeada y la base recta.
struct UnevenCapsula: Shape {
    var radio: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(radio, rect.width / 2, rect.height / 2)
        var camino = Path()
        camino.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        camino.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        camino.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r,
                      startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        camino.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        camino.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r,
                      startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        camino.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        camino.closeSubpath()
        return camino
    }
}
