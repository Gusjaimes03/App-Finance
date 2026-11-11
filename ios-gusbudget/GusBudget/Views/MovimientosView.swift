import SwiftUI

/// Todo lo que pasó en el mes: gastos, ingresos y pagos.
enum Movimiento: Identifiable {
    case gasto(Gasto)
    case agenda(AgendaItem)
    case fijo(PagoFijo, String)

    var id: String {
        switch self {
        case .gasto(let g): return "g_\(g.id.uuidString)"
        case .agenda(let a): return "a_\(a.id.uuidString)"
        case .fijo(let p, _): return "f_\(p.id)"
        }
    }

    var fecha: Date {
        switch self {
        case .gasto(let g): return g.fecha
        case .agenda(let a): return a.hechoFecha ?? a.fecha ?? a.creado
        case .fijo(let p, _): return p.fecha
        }
    }

    var monto: Decimal {
        switch self {
        case .gasto(let g): return g.monto
        case .agenda(let a): return a.valorEfectivo
        case .fijo(let p, _): return p.monto
        }
    }

    var esEntrada: Bool {
        if case .agenda(let a) = self { return a.tipo == .ingreso }
        return false
    }
}

struct MovimientosView: View {
    @EnvironmentObject private var store: FinanceStore

    enum Filtro: String, CaseIterable, Identifiable {
        case todo, gastos, entradas, pagos
        var id: String { rawValue }
        var titulo: String {
            switch self {
            case .todo: return "Todo"
            case .gastos: return "Gastos"
            case .entradas: return "Entradas"
            case .pagos: return "Pagos"
            }
        }
    }

    @State private var mes = Date().inicioDeMes
    @State private var filtro: Filtro = .todo
    @State private var busqueda = ""
    @State private var categoriaFiltro: String?
    @State private var gastoEditando: Gasto?

    // MARK: Datos

    private var movimientos: [Movimiento] {
        var lista: [Movimiento] = store.gastos(enMes: mes).map { Movimiento.gasto($0) }
        lista += store.data.agenda
            .filter { $0.hecho && ($0.hechoFecha ?? $0.fecha ?? $0.creado).mismoMes(que: mes) }
            .map { Movimiento.agenda($0) }
        lista += store.data.pagosFijos
            .filter { $0.fecha.mismoMes(que: mes) }
            .map { Movimiento.fijo($0, store.fijo($0.fijoId)?.nombre ?? "Gasto fijo") }
        return lista.sorted { $0.fecha > $1.fecha }
    }

    private var filtrados: [Movimiento] {
        let texto = busqueda.trimmingCharacters(in: .whitespaces).sinTildes
        return movimientos.filter { movimiento in
            guard coincide(movimiento, filtro: filtro) else { return false }

            if let categoriaFiltro {
                guard case .gasto(let g) = movimiento, g.cat == categoriaFiltro else { return false }
            }

            if !texto.isEmpty {
                return nombre(de: movimiento).sinTildes.contains(texto)
                    || detalle(de: movimiento).sinTildes.contains(texto)
            }
            return true
        }
    }

    private func coincide(_ movimiento: Movimiento, filtro: Filtro) -> Bool {
        switch (filtro, movimiento) {
        case (.todo, _): return true
        case (.gastos, .gasto(_)): return true
        case (.entradas, .agenda(let item)): return item.tipo == .ingreso
        case (.pagos, .fijo(_, _)): return true
        case (.pagos, .agenda(let item)): return item.tipo == .pago
        default: return false
        }
    }

    private var entro: Decimal {
        store.data.agenda
            .filter { $0.tipo == .ingreso && $0.hecho && ($0.hechoFecha ?? $0.fecha ?? $0.creado).mismoMes(que: mes) }
            .reduce(Decimal.zero) { $0 + $1.valorEfectivo }
    }

    private var salio: Decimal {
        let gastos = store.gastos(enMes: mes)
            .filter { $0.metodo != .credito }
            .reduce(Decimal.zero) { $0 + $1.monto }
        let pagos = store.data.agenda
            .filter { $0.tipo == .pago && $0.hecho && ($0.hechoFecha ?? $0.fecha ?? $0.creado).mismoMes(que: mes) }
            .reduce(Decimal.zero) { $0 + $1.valorEfectivo }
        let fijos = store.data.pagosFijos
            .filter { $0.fecha.mismoMes(que: mes) }
            .reduce(Decimal.zero) { $0 + $1.monto }
        return gastos + pagos + fijos
    }

    private var conCredito: Decimal {
        store.gastos(enMes: mes)
            .filter { $0.metodo == .credito }
            .reduce(Decimal.zero) { $0 + $1.monto }
    }

    struct GrupoDia: Identifiable {
        let fecha: Date
        let lista: [Movimiento]
        var id: Date { fecha }

        var total: Decimal {
            lista.reduce(Decimal.zero) { suma, movimiento in
                suma + (movimiento.esEntrada ? movimiento.monto : -movimiento.monto)
            }
        }
    }

    private var porDia: [GrupoDia] {
        Dictionary(grouping: filtrados) { $0.fecha.inicioDeDia }
            .map { GrupoDia(fecha: $0.key, lista: $0.value.sorted { $0.fecha > $1.fecha }) }
            .sorted { $0.fecha > $1.fecha }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    MesNavegador(mes: $mes)
                    kpis
                    donaMes
                    barrasMes
                    franjasMes
                    lista
                }
                .columna()
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.fondo)
            .navigationTitle("Movimientos")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $gastoEditando) { gasto in
                HojaGasto(gasto: gasto).environmentObject(store)
            }
        }
    }

    // MARK: Secciones

    private var kpis: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Mosaico(titulo: "Entró", valor: Fmt.plata(entro), color: Theme.verde)
                Mosaico(titulo: "Salió", valor: Fmt.plata(salio), color: Theme.rojo)
                Mosaico(
                    titulo: "Diferencia",
                    valor: Fmt.plata(entro - salio),
                    color: entro - salio < 0 ? Theme.rojo : Theme.texto
                )
            }
            if conCredito > 0 {
                Text("Con Guamacard gastaste \(Fmt.plata(conCredito)) este mes; eso se paga después.")
                    .font(.caption2)
                    .foregroundStyle(Theme.gris)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .panel()
    }

    @ViewBuilder
    private var donaMes: some View {
        let totales = store.totalesPorCategoria(mes: mes)
        if !totales.isEmpty {
            let total = totales.reduce(Decimal.zero) { $0 + $1.total }
            let tramos = totales.prefix(6).map {
                TramoDona(id: $0.categoria.id, valor: $0.total.doble, color: $0.categoria.color, nombre: $0.categoria.nombre)
            }
            VStack(alignment: .leading, spacing: 14) {
                TituloSeccion(texto: "En qué se fue tu plata")
                HStack(spacing: 14) {
                    Dona(tramos: tramos, total: total, lado: 124)
                    LeyendaDona(tramos: tramos, total: total)
                }
            }
            .panel()
        }
    }

    private var barrasMes: some View {
        VStack(alignment: .leading, spacing: 12) {
            TituloSeccion(
                texto: "Día por día",
                detalle: "La línea roja es tu presupuesto diario: \(Fmt.plata(store.presupuestoDiario(mes: mes)))"
            )
            BarrasPorDia(dias: store.totalesPorDia(mes: mes), presupuestoDiario: store.presupuestoDiario(mes: mes))
        }
        .panel()
    }

    @ViewBuilder
    private var franjasMes: some View {
        let resultado = store.franjas(mes: mes)
        let total = resultado.franjas.reduce(Decimal.zero) { $0 + $1.total }
        if total > 0 {
            VStack(alignment: .leading, spacing: 12) {
                TituloSeccion(texto: "Tus horarios")

                ForEach(resultado.franjas) { franja in
                    VStack(spacing: 5) {
                        HStack {
                            Text(franja.nombre)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.texto)
                            Text("· \(franja.cantidad)")
                                .font(.caption2)
                                .foregroundStyle(Theme.gris)
                            Spacer()
                            Text(Fmt.plata(franja.total))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.texto)
                        }
                        BarraProgreso(
                            avance: total > 0 ? franja.total.doble / total.doble : 0,
                            color: Theme.acento,
                            alto: 6
                        )
                        if let comun = franja.masComun {
                            Text("Lo más común: \(comun)")
                                .font(.caption2)
                                .foregroundStyle(Theme.gris)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                if resultado.sinHora > 0 {
                    Text("\(resultado.sinHora) gasto(s) sin hora anotada.")
                        .font(.caption2)
                        .foregroundStyle(Theme.gris)
                }

                let habitos = store.habitos()
                if !habitos.isEmpty {
                    Divider()
                    TituloSeccion(texto: "Lo que más repites")
                    ForEach(habitos.prefix(5)) { habito in
                        HStack(spacing: 10) {
                            IconoCuadro(
                                simbolo: store.categoria(habito.categoriaID).simbolo,
                                color: store.categoria(habito.categoriaID).color,
                                lado: 30
                            )
                            VStack(alignment: .leading, spacing: 1) {
                                Text(habito.titulo)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.texto)
                                Text(habito.descripcion)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.gris)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .panel()
        }
    }

    private var lista: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Filtro", selection: $filtro) {
                ForEach(Filtro.allCases) { opcion in
                    Text(opcion.titulo).tag(opcion)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(Theme.gris)
                TextField("Buscar", text: $busqueda)
                    .font(.subheadline)
                if !busqueda.isEmpty {
                    Button {
                        busqueda = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.gris)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(9)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Theme.fondo))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    chip(nombre: "Todas", activo: categoriaFiltro == nil) { categoriaFiltro = nil }
                    ForEach(store.categoriasVisibles) { categoria in
                        chip(nombre: categoria.nombre, activo: categoriaFiltro == categoria.id) {
                            categoriaFiltro = categoriaFiltro == categoria.id ? nil : categoria.id
                        }
                    }
                }
            }

            if porDia.isEmpty {
                Vacio(simbolo: "tray", texto: "No hay movimientos con ese filtro.")
            } else {
                ForEach(porDia) { grupo in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(Fmt.encabezadoDia(grupo.fecha))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.gris)
                            Spacer()
                            Text(Fmt.plata(grupo.total))
                                .font(.caption)
                                .foregroundStyle(Theme.gris)
                        }

                        ForEach(grupo.lista) { movimiento in
                            fila(movimiento)
                        }
                    }
                }
            }
        }
        .panel()
    }

    private func chip(nombre: String, activo: Bool, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            Text(nombre)
                .font(.caption)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(activo ? Theme.acento : Theme.fondo)
                )
                .foregroundStyle(activo ? Color.white : Theme.texto)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func fila(_ movimiento: Movimiento) -> some View {
        Button {
            if case .gasto(let gasto) = movimiento {
                gastoEditando = gasto
            }
        } label: {
            HStack(spacing: 11) {
                IconoCuadro(simbolo: simbolo(de: movimiento), color: color(de: movimiento), lado: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text(nombre(de: movimiento))
                        .font(.subheadline)
                        .foregroundStyle(Theme.texto)
                        .lineLimit(1)
                    Text(detalle(de: movimiento))
                        .font(.caption2)
                        .foregroundStyle(Theme.gris)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Text((movimiento.esEntrada ? "+" : "−") + Fmt.plata(movimiento.monto))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(movimiento.esEntrada ? Theme.verde : Theme.texto)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.plain)
    }

    private func nombre(de movimiento: Movimiento) -> String {
        switch movimiento {
        case .gasto(let g): return store.categoria(g.cat).nombre
        case .agenda(let a): return a.nombre
        case .fijo(_, let nombre): return nombre
        }
    }

    private func detalle(de movimiento: Movimiento) -> String {
        switch movimiento {
        case .gasto(let g):
            let metodo = g.metodo == .credito ? " · Guamacard" : ""
            return g.nota.isEmpty ? "Gasto\(metodo)" : "\(g.nota)\(metodo)"
        case .agenda(let a):
            return a.tipo == .ingreso ? "Entrada" : "Pago"
        case .fijo(_, _):
            return "Gasto fijo"
        }
    }

    private func simbolo(de movimiento: Movimiento) -> String {
        switch movimiento {
        case .gasto(let g): return store.categoria(g.cat).simbolo
        case .agenda(let a): return a.simbolo
        case .fijo(let p, _): return store.fijo(p.fijoId)?.simbolo ?? "calendar"
        }
    }

    private func color(de movimiento: Movimiento) -> Color {
        switch movimiento {
        case .gasto(let g): return store.categoria(g.cat).color
        case .agenda(let a): return a.tipo == .ingreso ? Theme.verde : Theme.acento
        case .fijo(_, _): return Theme.acento
        }
    }
}
