import SwiftUI

/// Tramo de la dona.
struct TramoDona: Identifiable {
    let id: String
    let valor: Double
    let color: Color
    let nombre: String
}

/// Dona "En qué se fue tu plata": total al centro y leyenda al lado.
struct Dona: View {
    let tramos: [TramoDona]
    let total: Decimal
    var grosor: CGFloat = 22
    var lado: CGFloat = 132

    private var suma: Double { max(tramos.reduce(0) { $0 + $1.valor }, 0.0001) }

    private struct Segmento: Identifiable {
        let id: String
        let color: Color
        let desde: Double
        let hasta: Double
    }

    private var segmentos: [Segmento] {
        var cursor: Double = 0
        var lista: [Segmento] = []
        for tramo in tramos where tramo.valor > 0 {
            let parte = tramo.valor / suma
            lista.append(Segmento(id: tramo.id, color: tramo.color, desde: cursor, hasta: min(cursor + parte, 1)))
            cursor += parte
        }
        return lista
    }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.linea, lineWidth: grosor)
            ForEach(segmentos) { segmento in
                Circle()
                    .trim(from: segmento.desde, to: segmento.hasta)
                    .stroke(segmento.color, style: StrokeStyle(lineWidth: grosor, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 1) {
                Text(Fmt.plata(total))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.texto)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("en el mes")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.gris)
            }
            .padding(grosor + 6)
        }
        .frame(width: lado, height: lado)
        .animation(.easeInOut(duration: 0.3), value: tramos.map(\.valor))
    }
}

/// Leyenda de la dona: color, nombre, valor y porcentaje.
struct LeyendaDona: View {
    let tramos: [TramoDona]
    let total: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(tramos) { tramo in
                HStack(spacing: 7) {
                    Circle().fill(tramo.color).frame(width: 8, height: 8)
                    Text(tramo.nombre)
                        .font(.caption)
                        .foregroundStyle(Theme.texto)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(Fmt.plata(Decimal(tramo.valor)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.texto)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(Fmt.porcentaje(total > 0 ? tramo.valor / total.doble : 0))
                        .font(.caption2)
                        .foregroundStyle(Theme.gris)
                        .frame(width: 38, alignment: .trailing)
                }
            }
        }
    }
}

/// Barras por día del mes con la línea punteada del presupuesto diario.
struct BarrasPorDia: View {
    let dias: [TotalDia]
    let presupuestoDiario: Decimal
    var alto: CGFloat = 120

    private var maximo: Double {
        max(dias.map { $0.total.doble }.max() ?? 0, presupuestoDiario.doble, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .bottomLeading) {
                    if presupuestoDiario > 0 {
                        let y = proxy.size.height * (1 - presupuestoDiario.doble / maximo)
                        Path { camino in
                            camino.move(to: CGPoint(x: 0, y: y))
                            camino.addLine(to: CGPoint(x: proxy.size.width, y: y))
                        }
                        .stroke(Theme.rojo.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }

                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(dias) { dia in
                            let valor = dia.total.doble
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(color(dia: dia, valor: valor))
                                .frame(height: max(2, proxy.size.height * valor / maximo))
                        }
                    }
                }
            }
            .frame(height: alto)

            HStack {
                Text("1")
                Spacer()
                Text("\(dias.count / 2)")
                Spacer()
                Text("\(dias.count)")
            }
            .font(.system(size: 9))
            .foregroundStyle(Theme.gris)
        }
    }

    private func color(dia: TotalDia, valor: Double) -> Color {
        if Calendar.app.isDateInToday(dia.fecha) { return Theme.sol }
        if presupuestoDiario > 0 && valor > presupuestoDiario.doble { return Theme.ambar }
        if valor == 0 { return Theme.linea }
        return Theme.acento
    }
}
