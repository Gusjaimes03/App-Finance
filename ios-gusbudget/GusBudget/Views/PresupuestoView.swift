import SwiftUI

/// Presupuesto del mes: lo planeado contra lo real (sección 2.3).
///
/// Estructura: hero con lo que te debería sobrar (y el anillo del día a día), el plan contra lo
/// real por grupos (lo que entra / lo que sale), el día a día por categoría con barras, los gastos
/// fijos y suscripciones con su check de "Ya pagué", y los pagos únicos (solo lectura).
struct PresupuestoView: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.ofrecerDeshacer) private var ofrecerDeshacer
    @Environment(\.irAPestana) private var irAPestana

    @State private var mes = Date().inicioDeMes
    @State private var solicitud: SolicitudValor?
    @State private var mostrarAjustar = false

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

    /// Categorías con tope o con gastos este mes (las demás no dicen nada).
    private var lineasCategoria: [LineaCategoria] {
        let gastosMes = store.gastos(enMes: mes)
        return store.categoriasVisibles.compactMap { categoria in
            let tope = store.presupuestoCategoria(categoria, mes: mes)
            let gastado = gastosMes
                .filter { $0.cat == categoria.id }
                .reduce(Decimal.zero) { $0 + $1.monto }
            guard tope > 0 || gastado > 0 else { return nil }
            return LineaCategoria(categoria: categoria, tope: tope, gastado: gastado)
        }
    }

    var body: some View {
        let r = resumen
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Espacio.seccion) {
                    hero(r)

                    if let tardio = store.sueldoTardio(mes: mes) {
                        BannerAviso(
                            simbolo: "clock.fill",
                            titulo: "\(tardio.nombre) llega a fin de mes",
                            mensaje: "Como llega en los últimos días, sirve sobre todo para el mes siguiente.",
                            tono: .aviso
                        )
                    }

                    planContraReal(r)
                    categorias(r)
                    seccionFijos
                    if !suscripciones.isEmpty { seccionSuscripciones }
                    if !pagosUnicos.isEmpty { seccionUnicos }
                    enlaceAjustar
                }
                .contenidoPantalla()
            }
            .fondoPantalla()
            .navigationTitle("Presupuesto")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Ajustar") {
                        mostrarAjustar = true
                    }
                    .fontWeight(.semibold)
                    .accessibilityLabel("Ajustar presupuesto")
                }
            }
            .conBotonAjustes()
            .navigationDestination(isPresented: $mostrarAjustar) {
                AjustarPresupuestoView().environmentObject(store)
            }
            .sheet(item: $solicitud) { peticion in
                HojaValorReal(solicitud: peticion)
            }
        }
    }

    // MARK: Hero

    private func hero(_ r: ResumenMes) -> some View {
        let sobra = r.resultadoPresupuesto >= 0
        return TarjetaHero(espaciado: Espacio.m) {
            MesNavegador(mes: $mes)

            VStack(alignment: .leading, spacing: Espacio.xxs) {
                Text(sobra ? "Este mes te debería sobrar" : "Este mes te faltaría")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.gris)
                CifraPlata(
                    valor: abs(r.resultadoPresupuesto),
                    estilo: .hero,
                    signo: .ninguno,
                    color: sobra ? Theme.sol : .white
                )
                if !sobra {
                    Insignia(texto: "Gastas más de lo que entra", tono: .negativo,
                             simbolo: "exclamationmark.triangle.fill")
                        .padding(.top, 2)
                }
            }
            .accessibilityElement(children: .combine)

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 0.5)
                .accessibilityHidden(true)

            HStack(alignment: .center, spacing: Espacio.m) {
                VStack {
                    AnilloProgreso(conPorcentaje: r.usadoDiaADia,
                                   color: Theme.colorAvance(r.usadoDiaADia),
                                   lado: 60)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Día a día usado")
                .accessibilityValue(Fmt.porcentaje(max(r.usadoDiaADia, 0)))

                ResumenDatos(datos: [
                    DatoResumen(titulo: "Gastado día a día", valor: r.diaADiaReal, signo: .ninguno),
                    DatoResumen(titulo: "Real hasta hoy", valor: r.resultadoReal)
                ], sobreOscuro: true)
            }
        }
    }

    // MARK: Plan contra real

    private func planContraReal(_ r: ResumenMes) -> some View {
        VStack(alignment: .leading, spacing: Espacio.titulo) {
            EncabezadoSeccion(titulo: "Plan del mes", detalle: "Lo que planeaste y lo que va hasta hoy")

            VStack(alignment: .leading, spacing: Espacio.m) {
                VStack(alignment: .leading, spacing: Espacio.xs) {
                    Sobrelinea(texto: "Lo que entra", color: Theme.verde)
                    VStack(spacing: 0) {
                        FilaPlan(simbolo: "banknote.fill", color: Theme.verde, titulo: "Sueldos",
                                 plan: r.sueldosPresupuesto, real: r.sueldosReal, entrada: true)
                        if r.extras > 0 {
                            SeparadorFila()
                            FilaPlan(simbolo: "plus.circle.fill", color: Theme.verde, titulo: "Extras",
                                     plan: nil, real: r.extras, entrada: true,
                                     nota: "Ingresos extra y préstamos que te devolvieron")
                        }
                        if r.prestadaPresupuesto > 0 {
                            SeparadorFila()
                            FilaPlan(simbolo: "arrow.uturn.left.circle.fill", color: Theme.ambar,
                                     titulo: "Plata prestada",
                                     plan: r.prestadaPresupuesto, real: r.prestadaReal, entrada: true,
                                     nota: "Hay que devolverla", colorNota: Theme.ambar)
                        }
                    }
                    .panel(padding: 0)
                }

                VStack(alignment: .leading, spacing: Espacio.xs) {
                    Sobrelinea(texto: "Lo que sale")
                    VStack(spacing: 0) {
                        FilaPlan(simbolo: "calendar", color: Theme.gris, titulo: "Gastos fijos",
                                 plan: r.fijosPresupuesto, real: r.fijosReal, entrada: false,
                                 nota: notaAhorroFijos(r),
                                 colorNota: r.ahorroFijos > 0 ? Theme.verde : Theme.ambar)
                        SeparadorFila()
                        FilaPlan(simbolo: "calendar.badge.clock", color: Theme.gris, titulo: "Pagos únicos",
                                 plan: r.unicosPresupuesto, real: r.unicosReal, entrada: false)
                        SeparadorFila()
                        FilaPlan(simbolo: "cart.fill", color: Theme.gris, titulo: "Día a día",
                                 plan: r.diaADiaPresupuesto, real: r.diaADiaReal, entrada: false,
                                 nota: "Llevas usado el \(Fmt.porcentaje(r.usadoDiaADia))")
                    }
                    .panel(padding: 0)
                }
            }
        }
    }

    private func notaAhorroFijos(_ r: ResumenMes) -> String? {
        if r.ahorroFijos > 0 { return "Te ahorraste \(Fmt.plata(r.ahorroFijos)) en lo ya pagado" }
        if r.ahorroFijos < 0 { return "Te pasaste \(Fmt.plata(-r.ahorroFijos)) en lo ya pagado" }
        return nil
    }

    // MARK: Día a día por categoría

    private func categorias(_ r: ResumenMes) -> some View {
        let lineas = lineasCategoria
        return VStack(alignment: .leading, spacing: Espacio.titulo) {
            EncabezadoSeccion(
                titulo: "Por categoría",
                detalle: "\(Fmt.plata(r.diaADiaReal)) de \(Fmt.plata(r.diaADiaPresupuesto)) del día a día"
            )

            if lineas.isEmpty {
                EstadoVacio(
                    simbolo: "chart.bar.fill",
                    titulo: "Ponle un tope a tus categorías",
                    mensaje: "Así sabes cuánto te queda en comida, transporte y lo demás.",
                    accionTitulo: "Poner topes",
                    accion: { mostrarAjustar = true }
                )
                .panel(padding: 0)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(lineas.enumerated()), id: \.element.id) { indice, linea in
                        if indice > 0 { SeparadorFila() }
                        FilaCategoriaPresupuesto(linea: linea)
                    }
                }
                .panel(padding: 0)
            }
        }
    }

    // MARK: Gastos fijos y suscripciones

    private var seccionFijos: some View {
        let lista = fijosDelMes
        let pagados = lista.filter { store.pagoDeFijo($0.id, periodo: periodo) != nil }.count
        return VStack(alignment: .leading, spacing: Espacio.titulo) {
            EncabezadoSeccion(
                titulo: "Gastos fijos",
                detalle: lista.isEmpty ? nil : "\(pagados) de \(lista.count) pagados"
            )

            if lista.isEmpty {
                EstadoVacio(
                    simbolo: "calendar",
                    titulo: "Sin gastos fijos este mes",
                    mensaje: "Agrega el arriendo, los servicios o las cuotas para tenerlos en cuenta.",
                    accionTitulo: "Agregar gasto fijo",
                    accion: { mostrarAjustar = true }
                )
                .panel(padding: 0)
            } else {
                grupoFijos(lista)
            }
        }
    }

    private var seccionSuscripciones: some View {
        let lista = suscripciones
        let total = lista.reduce(Decimal.zero) { $0 + (store.montoFijo($1) ?? 0) }
        return VStack(alignment: .leading, spacing: Espacio.titulo) {
            EncabezadoSeccion(titulo: "Suscripciones", detalle: "\(Fmt.plata(total)) al mes")
            grupoFijos(lista)
        }
    }

    private func grupoFijos(_ lista: [Fijo]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(lista.enumerated()), id: \.element.id) { indice, fijo in
                // Alineado con el texto: 16 de margen − 6 + 44 del check + 12.
                if indice > 0 { SeparadorFila(sangria: 66) }
                filaFijo(fijo)
            }
        }
        .panel(padding: 0)
    }

    @ViewBuilder
    private func filaFijo(_ fijo: Fijo) -> some View {
        let pago = store.pagoDeFijo(fijo.id, periodo: periodo)
        let presupuestado = store.montoFijo(fijo) ?? 0

        HStack(spacing: Espacio.s) {
            BotonCheck(
                hecho: pago != nil,
                etiqueta: pago == nil ? "Ya pagué: \(fijo.nombre)" : "Deshacer pago: \(fijo.nombre)"
            ) {
                if let pago {
                    deshacerPago(pago, de: fijo)
                } else {
                    pedirPago(fijo, sugerido: presupuestado)
                }
            }
            .padding(.leading, -6)

            VStack(alignment: .leading, spacing: 3) {
                Text(fijo.nombre)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.texto)
                    .lineLimit(2)
                subtituloFijo(fijo, pago: pago)
                    .font(.subheadline)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                if let pago {
                    CifraPlata(valor: pago.monto, estilo: .normal, signo: .ninguno)
                    if pago.presupuesto != pago.monto {
                        Text("de \(Fmt.plata(pago.presupuesto))")
                            .font(.footnote)
                            .foregroundStyle(Theme.gris)
                            .lineLimit(1)
                    }
                } else if presupuestado > 0 {
                    CifraPlata(valor: presupuestado, estilo: .normal, signo: .ninguno)
                } else {
                    Text("Sin valor")
                        .font(.subheadline)
                        .foregroundStyle(Theme.grisClaro)
                }
            }
            .layoutPriority(1)

            MenuMas(etiqueta: "Opciones de \(fijo.nombre)") {
                accionesFijo(fijo, pago: pago, presupuestado: presupuestado)
            }
            .padding(.trailing, -6)
        }
        .padding(.vertical, Espacio.xs)
        .padding(.horizontal, Espacio.m)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
        .contextMenu {
            accionesFijo(fijo, pago: pago, presupuestado: presupuestado)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(fijo.nombre)
        .accessibilityValue(descripcionFijo(fijo, pago: pago, presupuestado: presupuestado))
        .accessibilityAction {
            if let pago {
                corregirPago(pago, de: fijo)
            } else {
                pedirPago(fijo, sugerido: presupuestado)
            }
        }
        .accessibilityActions {
            accionesFijo(fijo, pago: pago, presupuestado: presupuestado)
        }
    }

    @ViewBuilder
    private func subtituloFijo(_ fijo: Fijo, pago: PagoFijo?) -> some View {
        if let pago {
            Text("Pagado el \(Fmt.fechaCorta(pago.fecha))"
                 + (pago.ahorro > 0 ? " · ahorraste \(Fmt.plata(pago.ahorro))" : ""))
                .foregroundStyle(Theme.verde)
        } else if let usd = fijo.usd {
            Text("USD \(Fmt.numero(usd)) × \(Fmt.plata(store.data.trm))"
                 + (fijo.dia.map { " · vence el \($0)" } ?? ""))
                .foregroundStyle(Theme.gris)
        } else if let dia = fijo.dia {
            Text("Vence el \(dia)")
                .foregroundStyle(Theme.gris)
        } else {
            Text("Sin día de pago")
                .foregroundStyle(Theme.gris)
        }
    }

    @ViewBuilder
    private func accionesFijo(_ fijo: Fijo, pago: PagoFijo?, presupuestado: Decimal) -> some View {
        if let pago {
            Button {
                corregirPago(pago, de: fijo)
            } label: {
                Label("Corregir valor", systemImage: "pencil")
            }
            Button {
                deshacerPago(pago, de: fijo)
            } label: {
                Label("Deshacer pago", systemImage: "arrow.uturn.backward")
            }
        } else {
            Button {
                pedirPago(fijo, sugerido: presupuestado)
            } label: {
                Label("Ya pagué", systemImage: "checkmark.circle")
            }
        }
    }

    private func descripcionFijo(_ fijo: Fijo, pago: PagoFijo?, presupuestado: Decimal) -> String {
        if let pago {
            var texto = "Pagado, \(CifraPlata.textoAccesible(pago.monto, signo: .ninguno)), el \(Fmt.fechaCorta(pago.fecha))"
            if pago.ahorro > 0 { texto += ". Te ahorraste \(CifraPlata.textoAccesible(pago.ahorro, signo: .ninguno))" }
            return texto
        }
        var texto = "Pendiente"
        if presupuestado > 0 { texto += ", \(CifraPlata.textoAccesible(presupuestado, signo: .ninguno))" }
        if let dia = fijo.dia { texto += ", vence el \(dia)" }
        return texto
    }

    // MARK: Acciones de fijos

    private func pedirPago(_ fijo: Fijo, sugerido: Decimal) {
        let periodoActual = periodo
        let ofrecer = ofrecerDeshacer
        let tienda = store
        solicitud = SolicitudValor(
            titulo: fijo.nombre,
            pregunta: "¿Cuánto pagaste de verdad?",
            montoSugerido: sugerido,
            fechaSugerida: Date()
        ) { monto, fecha in
            tienda.pagarFijo(fijo, periodo: periodoActual, monto: monto, fecha: fecha)
            ofrecer(nil) {
                if let nuevo = tienda.pagoDeFijo(fijo.id, periodo: periodoActual) {
                    tienda.deshacerPagoFijo(nuevo)
                }
            }
        }
    }

    private func corregirPago(_ pago: PagoFijo, de fijo: Fijo) {
        solicitud = SolicitudValor(
            titulo: fijo.nombre,
            pregunta: "¿Cuánto pagaste de verdad?",
            montoSugerido: pago.monto,
            fechaSugerida: pago.fecha
        ) { monto, _ in
            store.corregirPagoFijo(pago, monto: monto)
        }
    }

    private func deshacerPago(_ pago: PagoFijo, de fijo: Fijo) {
        let periodoActual = periodo
        let tienda = store
        tienda.deshacerPagoFijo(pago)
        ofrecerDeshacer(nil) {
            // Si ya lo volvió a marcar pagado, no se paga dos veces (ni se descuenta la deuda dos veces).
            guard tienda.pagoDeFijo(fijo.id, periodo: periodoActual) == nil else { return }
            let actual = tienda.fijo(fijo.id) ?? fijo
            tienda.pagarFijo(actual, periodo: periodoActual, monto: pago.monto, fecha: pago.fecha)
        }
    }

    // MARK: Pagos únicos (solo lectura: se manejan en Pagos)

    private var seccionUnicos: some View {
        VStack(alignment: .leading, spacing: Espacio.titulo) {
            EncabezadoSeccion(
                titulo: "Pagos únicos",
                detalle: "Los marcas en Pagos",
                accionTitulo: "Ver en Pagos",
                accion: { irAPestana(.pagos) }
            )
            VStack(spacing: 0) {
                ForEach(Array(pagosUnicos.enumerated()), id: \.element.id) { indice, item in
                    if indice > 0 { SeparadorFila() }
                    FilaLista(
                        simbolo: item.simbolo,
                        color: item.hecho ? Theme.verde : Theme.gris,
                        titulo: item.nombre,
                        subtitulo: item.mesContable.map { Fmt.diaYMes($0) },
                        insignia: Insignia(texto: item.hecho ? "Pagado" : "Pendiente",
                                           tono: item.hecho ? .positivo : .neutro)
                    ) {
                        CifraPlata(valor: item.valorEfectivo, estilo: .normal, signo: .ninguno)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .panel(padding: 0)
        }
    }

    // MARK: Ajustar

    private var enlaceAjustar: some View {
        Button {
            mostrarAjustar = true
        } label: {
            FilaLista(
                simbolo: "slider.horizontal.3",
                color: Theme.acento,
                titulo: "Ajustar presupuesto",
                subtitulo: "Topes por categoría, gastos fijos y suscripciones"
            ) {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.grisClaro)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.presionable)
        .panel(padding: 0)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Filas privadas

/// Una categoría con su tope y lo gastado en el mes.
private struct LineaCategoria: Identifiable {
    let categoria: Categoria
    let tope: Decimal
    let gastado: Decimal

    var id: String { categoria.id }
    var usado: Double { tope > 0 ? gastado.doble / tope.doble : 1 }
}

/// Fila "plan contra real": la cifra real grande bajo el nombre, "de $plan" pequeño a la derecha y la barra.
private struct FilaPlan: View {
    let simbolo: String
    let color: Color
    let titulo: String
    /// `nil` = no hay plan (por ejemplo, los extras): sin barra ni línea de plan.
    let plan: Decimal?
    let real: Decimal
    let entrada: Bool
    var nota: String? = nil
    var colorNota: Color = Theme.gris

    private var avance: Double {
        guard let plan, plan > 0 else { return 0 }
        return real.doble / plan.doble
    }

    private var signo: CifraPlata.Signo {
        guard real > 0 else { return .ninguno }
        return entrada ? .entrada : .salida
    }

    var body: some View {
        HStack(alignment: .top, spacing: Espacio.s) {
            IconoCuadro(simbolo: simbolo, color: color, lado: 40)

            VStack(alignment: .leading, spacing: 6) {
                Text(titulo)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.gris)
                    .lineLimit(2)

                HStack(alignment: .firstTextBaseline, spacing: Espacio.xs) {
                    CifraPlata(valor: real, estilo: .media, signo: signo)
                        .layoutPriority(1)
                    Spacer(minLength: Espacio.xs)
                    if let plan {
                        Text("de \(Fmt.plata(plan))")
                            .font(.footnote)
                            .monospacedDigit()
                            .foregroundStyle(Theme.gris)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .padding(.top, -4)

                if let plan, plan > 0 {
                    BarraProgreso(
                        avance: avance,
                        color: entrada ? Theme.verde : Theme.colorAvance(avance),
                        alto: 6
                    )
                }

                if let nota {
                    Text(nota)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(colorNota)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, Espacio.s)
        .padding(.horizontal, Espacio.m)
        .frame(minHeight: 60)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(titulo)
        .accessibilityValue(descripcion)
    }

    private var descripcion: String {
        var partes = ["Hasta hoy \(CifraPlata.textoAccesible(real, signo: .ninguno))"]
        if let plan { partes.append("plan \(CifraPlata.textoAccesible(plan, signo: .ninguno))") }
        if let nota { partes.append(nota) }
        return partes.joined(separator: ", ")
    }
}

/// Categoría del día a día: gastado a la derecha, barra con color de estado y lo que queda.
private struct FilaCategoriaPresupuesto: View {
    let linea: LineaCategoria

    private var pasado: Bool { linea.tope > 0 && linea.gastado > linea.tope }

    var body: some View {
        HStack(alignment: .top, spacing: Espacio.s) {
            IconoCuadro(simbolo: linea.categoria.simbolo, color: linea.categoria.color, lado: 40)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: Espacio.xs) {
                    Text(linea.categoria.nombre)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.texto)
                        .lineLimit(1)
                    Spacer(minLength: Espacio.xs)
                    CifraPlata(valor: linea.gastado, estilo: .normal, signo: .ninguno)
                        .layoutPriority(1)
                }

                if linea.tope > 0 {
                    BarraProgreso(avance: linea.usado, color: Theme.colorAvance(linea.usado), alto: 8)
                    HStack(spacing: Espacio.xs) {
                        Text(pasado
                             ? "Te pasaste \(Fmt.plata(linea.gastado - linea.tope))"
                             : "Te quedan \(Fmt.plata(linea.tope - linea.gastado))")
                            .font(.footnote.weight(pasado ? .semibold : .regular))
                            .foregroundStyle(pasado ? Theme.rojo : Theme.gris)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: Espacio.xs)
                        Text("de \(Fmt.plata(linea.tope))")
                            .font(.footnote)
                            .foregroundStyle(Theme.gris)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                } else {
                    Text("Sin tope")
                        .font(.footnote)
                        .foregroundStyle(Theme.gris)
                }
            }
        }
        .padding(.vertical, Espacio.s)
        .padding(.horizontal, Espacio.m)
        .frame(minHeight: 60)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(linea.categoria.nombre)
        .accessibilityValue(descripcion)
    }

    private var descripcion: String {
        let gastado = CifraPlata.textoAccesible(linea.gastado, signo: .ninguno)
        guard linea.tope > 0 else { return "Gastado \(gastado), sin tope" }
        let tope = CifraPlata.textoAccesible(linea.tope, signo: .ninguno)
        let resto = pasado
            ? "te pasaste \(CifraPlata.textoAccesible(linea.gastado - linea.tope, signo: .ninguno))"
            : "te quedan \(CifraPlata.textoAccesible(linea.tope - linea.gastado, signo: .ninguno))"
        return "Gastado \(gastado) de \(tope), \(Fmt.porcentaje(linea.usado)), \(resto)"
    }
}
