import SwiftUI

/// Presupuesto del mes: lo planeado contra lo real (sección 2.3).
struct PresupuestoView: View {
    @EnvironmentObject private var store: FinanceStore

    @State private var mes = Date().inicioDeMes
    @State private var solicitud: SolicitudValor?

    private var resumen: ResumenMes { store.resumen(mes: mes) }
    private var periodo: String { mes.clavePeriodo }

    private var fijosDelMes: [Fijo] {
        store.data.fijos.filter { $0.aplicaEn(periodo: periodo) && !$0.esSuscripcion }
    }

    private var suscripciones: [Fijo] {
        store.data.fijos.filter { $0.aplicaEn(periodo: periodo) && $0.esSuscripcion }
    }

    private var pagosUnicos: [AgendaItem] {
        store.data.agenda.filter { item in
            item.tipo == .pago && (item.mesContable?.mismoMes(que: mes) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    MesNavegador(mes: $mes)
                    tabla
                    diaADia
                    fijos
                    NavigationLink {
                        AjustarPresupuestoView().environmentObject(store)
                    } label: {
                        Label("Ajustar mi presupuesto y categorías", systemImage: "slider.horizontal.3")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.acento)
                }
                .columna()
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.fondo)
            .navigationTitle("Presupuesto")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $solicitud) { peticion in
                HojaValorReal(solicitud: peticion)
            }
        }
    }

    // MARK: Tabla resumen

    private var tabla: some View {
        VStack(spacing: 10) {
            HStack {
                Text("")
                Spacer()
                Text("Presupuesto")
                    .frame(width: 92, alignment: .trailing)
                Text("Real hasta hoy")
                    .frame(width: 92, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Theme.gris)

            fila("Sueldos", resumen.sueldosPresupuesto, resumen.sueldosReal)
            if resumen.extras > 0 {
                fila("Extras y préstamos devueltos", resumen.extras, resumen.extras)
            }
            if resumen.prestadaPresupuesto > 0 {
                fila("Plata prestada (hay que devolverla)", resumen.prestadaPresupuesto, resumen.prestadaReal)
            }
            fila("Gastos fijos", resumen.fijosPresupuesto, resumen.fijosReal, negativo: true)
            if resumen.ahorroFijos != 0 {
                Text(resumen.ahorroFijos > 0
                     ? "Te ahorraste \(Fmt.plata(resumen.ahorroFijos)) en lo ya pagado"
                     : "Te pasaste \(Fmt.plata(-resumen.ahorroFijos)) en lo ya pagado")
                    .font(.caption2)
                    .foregroundStyle(resumen.ahorroFijos > 0 ? Theme.verde : Theme.ambar)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            fila("Pagos únicos", resumen.unicosPresupuesto, resumen.unicosReal, negativo: true)
            fila("Día a día", resumen.diaADiaPresupuesto, resumen.diaADiaReal, negativo: true)
            Text("Llevas usado el \(Fmt.porcentaje(resumen.usadoDiaADia)) del día a día")
                .font(.caption2)
                .foregroundStyle(Theme.gris)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            HStack {
                Text(resumen.resultadoPresupuesto >= 0 ? "Te debería sobrar" : "Te faltaría")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.texto)
                Spacer()
                Text(Fmt.plata(abs(resumen.resultadoPresupuesto)))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(resumen.resultadoPresupuesto >= 0 ? Theme.verde : Theme.rojo)
                    .frame(width: 92, alignment: .trailing)
                Text(Fmt.plata(resumen.resultadoReal))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(resumen.resultadoReal >= 0 ? Theme.verde : Theme.rojo)
                    .frame(width: 92, alignment: .trailing)
            }

            if let tardio = store.sueldoTardio(mes: mes) {
                Text("Ojo: \(tardio.nombre) llega en los últimos días del mes, así que sirve sobre todo para el mes siguiente.")
                    .font(.caption2)
                    .foregroundStyle(Theme.ambar)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .panel()
    }

    private func fila(_ titulo: String, _ presupuesto: Decimal, _ real: Decimal, negativo: Bool = false) -> some View {
        HStack {
            Text(titulo)
                .font(.caption)
                .foregroundStyle(Theme.texto)
                .lineLimit(2)
            Spacer(minLength: 4)
            Text((negativo && presupuesto > 0 ? "−" : "") + Fmt.plata(presupuesto))
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.texto)
                .frame(width: 92, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text((negativo && real > 0 ? "−" : "") + Fmt.plata(real))
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.gris)
                .frame(width: 92, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    // MARK: Día a día por categoría

    private var diaADia: some View {
        VStack(alignment: .leading, spacing: 12) {
            TituloSeccion(texto: "Día a día por categoría")

            HStack {
                Text("Total día a día")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.texto)
                Spacer()
                Text("\(Fmt.plata(resumen.diaADiaReal)) de \(Fmt.plata(resumen.diaADiaPresupuesto))")
                    .font(.caption)
                    .foregroundStyle(Theme.gris)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            BarraProgreso(
                avance: resumen.usadoDiaADia,
                color: colorBarra(usado: resumen.usadoDiaADia)
            )

            Divider()

            ForEach(store.categoriasVisibles) { categoria in
                filaCategoria(categoria)
            }
        }
        .panel()
    }

    @ViewBuilder
    private func filaCategoria(_ categoria: Categoria) -> some View {
        let tope = store.presupuestoCategoria(categoria, mes: mes)
        let gastado = store.gastos(enMes: mes)
            .filter { $0.cat == categoria.id }
            .reduce(Decimal.zero) { $0 + $1.monto }

        if tope > 0 || gastado > 0 {
            let usado = tope > 0 ? gastado.doble / tope.doble : 1
            VStack(spacing: 5) {
                HStack(spacing: 9) {
                    IconoCuadro(simbolo: categoria.simbolo, color: categoria.color, lado: 28)
                    Text(categoria.nombre)
                        .font(.caption)
                        .foregroundStyle(Theme.texto)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(tope > 0 ? "\(Fmt.plata(gastado)) de \(Fmt.plata(tope))" : Fmt.plata(gastado))
                        .font(.caption2)
                        .foregroundStyle(Theme.gris)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if tope > 0 {
                    BarraProgreso(avance: usado, color: colorBarra(usado: usado), alto: 6)
                    Text(gastado > tope
                         ? "Te pasaste \(Fmt.plata(gastado - tope))"
                         : "Te quedan \(Fmt.plata(tope - gastado))")
                        .font(.system(size: 10))
                        .foregroundStyle(gastado > tope ? Theme.rojo : Theme.gris)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Sin presupuesto")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.gris)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func colorBarra(usado: Double) -> Color {
        if usado > 1 { return Theme.rojo }
        if usado >= 0.8 { return Theme.sol }
        return Theme.acento
    }

    // MARK: Gastos fijos del mes

    private var fijos: some View {
        VStack(alignment: .leading, spacing: 12) {
            TituloSeccion(texto: "Gastos fijos y pagos del mes")

            ForEach(fijosDelMes) { fijo in
                filaFijo(fijo)
            }

            if !suscripciones.isEmpty {
                Divider()
                HStack {
                    Text("Suscripciones")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.texto)
                    Spacer()
                    Text(Fmt.plata(suscripciones.reduce(Decimal.zero) { $0 + (store.montoFijo($1) ?? 0) }))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.gris)
                }
                ForEach(suscripciones) { fijo in
                    filaFijo(fijo)
                }
            }

            if !pagosUnicos.isEmpty {
                Divider()
                Text("Pagos únicos del mes")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.texto)
                ForEach(pagosUnicos) { item in
                    HStack(spacing: 10) {
                        IconoCuadro(simbolo: item.simbolo, color: Theme.acento, lado: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.nombre)
                                .font(.subheadline)
                                .foregroundStyle(Theme.texto)
                                .lineLimit(1)
                            Text(item.hecho ? "Pagado" : "Pendiente")
                                .font(.caption2)
                                .foregroundStyle(item.hecho ? Theme.verde : Theme.gris)
                        }
                        Spacer(minLength: 4)
                        Text(Fmt.plata(item.valorEfectivo))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.texto)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
        .panel()
    }

    @ViewBuilder
    private func filaFijo(_ fijo: Fijo) -> some View {
        let pago = store.pagoDeFijo(fijo.id, periodo: periodo)
        let presupuestado = store.montoFijo(fijo) ?? 0

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                IconoCuadro(simbolo: fijo.simbolo, color: pago == nil ? Theme.acento : Theme.verde, lado: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text(fijo.nombre)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.texto)
                        .lineLimit(1)

                    if let pago {
                        Text("Pagaste \(Fmt.plata(pago.monto)) el \(Fmt.fechaCorta(pago.fecha))"
                             + (pago.ahorro > 0 ? " · te ahorraste \(Fmt.plata(pago.ahorro))" : ""))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.verde)
                            .lineLimit(2)
                    } else if let usd = fijo.usd {
                        Text("USD \(Fmt.numero(usd)) × \(Fmt.plata(store.data.trm))")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.gris)
                    } else if let dia = fijo.dia {
                        Text("Vence el \(dia)")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.gris)
                    } else {
                        Text("Sin día de pago")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.gris)
                    }
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(presupuestado > 0 ? Fmt.plata(pago?.monto ?? presupuestado) : "Sin valor")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.texto)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let pago, pago.presupuesto != pago.monto {
                        Text("de \(Fmt.plata(pago.presupuesto))")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.gris)
                    }
                }
            }

            HStack(spacing: 8) {
                Spacer()
                if let pago {
                    Button("Corregir valor") {
                        solicitud = SolicitudValor(
                            titulo: fijo.nombre,
                            pregunta: "¿Cuánto pagaste de verdad?",
                            montoSugerido: pago.monto,
                            fechaSugerida: pago.fecha
                        ) { monto, _ in
                            store.corregirPagoFijo(pago, monto: monto)
                        }
                    }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button("Deshacer") { store.deshacerPagoFijo(pago) }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                } else {
                    Button("Ya pagué") {
                        solicitud = SolicitudValor(
                            titulo: fijo.nombre,
                            pregunta: "¿Cuánto pagaste de verdad?",
                            montoSugerido: presupuestado,
                            fechaSugerida: Date()
                        ) { monto, fecha in
                            store.pagarFijo(fijo, periodo: periodo, monto: monto, fecha: fecha)
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.acento)
                    .controlSize(.mini)
                }
            }
        }
        .padding(.vertical, 3)
    }
}
