import SwiftUI

/// Lo tuyo en plata (libre + cajitas), cajitas, lo que te deben y lo que debes.
struct BalanceView: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.ofrecerDeshacer) private var ofrecerDeshacer
    @Environment(\.dynamicTypeSize) private var tamanoLetra

    @State private var solicitud: SolicitudValor?
    @State private var mostrarPrestamo = false
    @State private var mostrarDeuda = false
    @State private var mostrarCajita = false
    @State private var quitandoCajita: Cajita?
    @State private var borrandoDeuda: Deuda?
    @State private var edicion: EdicionDato?

    private var cajitasOrdenadas: [Cajita] {
        store.data.cajitas.sorted(by: { $0.orden < $1.orden })
    }

    private var deudasOrdenadas: [Deuda] {
        store.data.deudas.sorted(by: { $0.orden < $1.orden })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Espacio.seccion) {
                    patrimonio
                    cajitas
                    meDeben
                    debo
                }
                .contenidoPantalla()
            }
            .scrollDismissesKeyboard(.interactively)
            .fondoPantalla()
            .navigationTitle("Balance")
            .navigationBarTitleDisplayMode(.large)
            .conBotonAjustes()
            .sheet(item: $solicitud) { peticion in
                HojaValorReal(solicitud: peticion)
            }
            .sheet(isPresented: $mostrarPrestamo) {
                HojaPrestamo().environmentObject(store)
            }
            .sheet(isPresented: $mostrarDeuda) {
                HojaNuevaDeuda().environmentObject(store)
            }
            .sheet(isPresented: $mostrarCajita) {
                HojaNuevaCajitaBalance().environmentObject(store)
            }
            .hojaEdicion($edicion)
            .confirmationDialog(
                "¿Borrar la cajita \(quitandoCajita?.nombre ?? "")?",
                isPresented: Binding(get: { quitandoCajita != nil }, set: { if !$0 { quitandoCajita = nil } }),
                titleVisibility: .visible
            ) {
                if let cajita = quitandoCajita {
                    Button("Borrar cajita", role: .destructive) {
                        let tienda = store
                        tienda.quitarCajita(cajita)
                        ofrecerDeshacer { tienda.restaurarCajita(cajita) }
                        quitandoCajita = nil
                    }
                }
                Button("Cancelar", role: .cancel) { quitandoCajita = nil }
            } message: {
                if let cajita = quitandoCajita {
                    Text("Los \(Fmt.plata(cajita.guardado)) vuelven a tu plata libre.")
                }
            }
        }
        .confirmationDialog(
            "¿Borrar la deuda \(borrandoDeuda?.nombre ?? "")?",
            isPresented: Binding(get: { borrandoDeuda != nil }, set: { if !$0 { borrandoDeuda = nil } }),
            titleVisibility: .visible
        ) {
            if let deuda = borrandoDeuda {
                Button("Borrar deuda", role: .destructive) {
                    let tienda = store
                    tienda.quitarDeuda(deuda)
                    ofrecerDeshacer { tienda.restaurarDeuda(deuda) }
                    borrandoDeuda = nil
                }
            }
            Button("Cancelar", role: .cancel) { borrandoDeuda = nil }
        } message: {
            if let deuda = borrandoDeuda {
                Text(deuda.pagada
                     ? "Ya está pagada. Sus abonos siguen en tus movimientos."
                     : "Todavía debes \(Fmt.plata(deuda.saldo)). Sus abonos siguen en tus movimientos.")
            }
        }
    }

    // MARK: Patrimonio

    private var patrimonio: some View {
        let total = store.patrimonio
        let libre = store.libre

        return TarjetaHero(espaciado: Espacio.s) {
            HStack(spacing: Espacio.xs) {
                Text("Lo tuyo, en plata")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.gris)
                Spacer(minLength: 0)
                if total < 0 {
                    Insignia(texto: "En rojo", tono: .negativo)
                }
            }

            CifraPlata(valor: total, estilo: .hero, signo: .automatico, color: .white)

            Text("La plata que tienes hoy: tu plata libre más lo que hay en las cajitas.")
                .font(.footnote)
                .foregroundStyle(Theme.gris)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: Espacio.s) {
                ResumenDatos(
                    datos: [
                        DatoResumen(titulo: "Plata libre", valor: libre, signo: .automatico,
                                    color: libre < 0 ? Theme.rojo : nil),
                        DatoResumen(titulo: "En cajitas", valor: store.enCajitas, signo: .ninguno)
                    ],
                    sobreOscuro: true
                )
                Rectangle()
                    .fill(Color.white.opacity(0.14))
                    .frame(height: 0.5)
                    .accessibilityHidden(true)
                ResumenDatos(
                    datos: [
                        DatoResumen(titulo: "Me deben", valor: store.totalMeDeben,
                                    signo: store.totalMeDeben > 0 ? .entrada : .ninguno,
                                    color: store.totalMeDeben > 0 ? Theme.verde : nil),
                        DatoResumen(titulo: "Debo", valor: store.totalDebo,
                                    signo: store.totalDebo > 0 ? .salida : .ninguno,
                                    color: store.totalDebo > 0 ? Theme.rojo : nil)
                    ],
                    sobreOscuro: true
                )
            }
            .padding(.top, Espacio.xxs)

            Text("Lo que te deben y lo que debes va aparte: no se suma porque no es plata que tengas.")
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Espacio.xxs)
        }
    }

    // MARK: Cajitas

    private var columnasCajitas: [GridItem] {
        if tamanoLetra.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return [GridItem(.flexible(), spacing: Espacio.s), GridItem(.flexible(), spacing: Espacio.s)]
    }

    private var cajitas: some View {
        let lista = cajitasOrdenadas
        return VStack(alignment: .leading, spacing: Espacio.titulo) {
            EncabezadoSeccion(
                titulo: "Cajitas",
                detalle: lista.isEmpty ? "Plata apartada para algo" : "\(Fmt.plata(store.enCajitas)) apartados",
                accionTitulo: lista.isEmpty ? nil : "+ Nueva cajita",
                accion: { mostrarCajita = true }
            )

            if lista.isEmpty {
                EstadoVacio(
                    simbolo: "tray.and.arrow.down",
                    titulo: "Crea tu primera cajita",
                    mensaje: "Aparta plata para algo: un viaje, la matrícula o una emergencia. No la gastas sin darte cuenta.",
                    accionTitulo: "+ Nueva cajita",
                    accion: { mostrarCajita = true }
                )
                .background(FondoTarjeta())
            } else {
                // Grid (no LazyVGrid): las dos tarjetas de cada fila quedan del mismo alto
                // y los botones "Guardar plata" alineados.
                let porFila = columnasCajitas.count
                let filas = stride(from: 0, to: lista.count, by: porFila).map {
                    Array(lista[$0..<min($0 + porFila, lista.count)])
                }
                Grid(alignment: .topLeading, horizontalSpacing: Espacio.s, verticalSpacing: Espacio.s) {
                    ForEach(filas, id: \.first?.id) { fila in
                        GridRow {
                            ForEach(fila) { cajita in
                                tarjeta(cajita)
                            }
                            if fila.count < porFila {
                                Color.clear.gridCellUnsizedAxes([.vertical])
                            }
                        }
                    }
                }
            }
        }
    }

    private func tarjeta(_ cajita: Cajita) -> some View {
        TarjetaCajitaBalance(
            cajita: cajita,
            para: nombreDestino(de: cajita),
            alGuardar: { pedirGuardar(cajita) },
            alSacar: { pedirSacar(cajita) },
            alEditar: { edicion = .cajita(cajita.id) },
            alBorrar: {
                Haptics.warning()
                quitandoCajita = cajita
            }
        )
    }

    /// Nombre del pago o fijo que cubre la cajita, si tiene uno.
    private func nombreDestino(de cajita: Cajita) -> String? {
        guard let para = cajita.para else { return nil }
        if let fijo = store.fijo(para) { return fijo.nombre }
        return store.data.agenda.first(where: { $0.id.uuidString == para })?.nombre
    }

    private func pedirGuardar(_ cajita: Cajita) {
        let sugerido = min(cajita.falta, max(0, store.libre))
        solicitud = SolicitudValor(
            titulo: cajita.nombre,
            pregunta: "¿Cuánto guardas?",
            montoSugerido: sugerido
        ) { monto, _ in
            store.guardarEnCajita(cajita, monto: monto)
            let valor = monto.redondeado
            if valor > 0 {
                ofrecerDeshacer { store.sacarDeCajita(cajita, monto: valor) }
            }
        }
    }

    private func pedirSacar(_ cajita: Cajita) {
        solicitud = SolicitudValor(
            titulo: cajita.nombre,
            pregunta: "¿Cuánto sacas?",
            montoSugerido: cajita.guardado
        ) { monto, _ in
            let antes = store.data.cajitas.first(where: { $0.id == cajita.id })?.guardado ?? cajita.guardado
            store.sacarDeCajita(cajita, monto: monto)
            let sacado = min(antes, monto.redondeado)
            if sacado > 0 {
                ofrecerDeshacer { store.guardarEnCajita(cajita, monto: sacado) }
            }
        }
    }

    // MARK: Me deben

    private var meDeben: some View {
        let cobros = store.cobrosPendientes
        return VStack(alignment: .leading, spacing: Espacio.titulo) {
            EncabezadoSeccion(
                titulo: "Me deben",
                detalle: cobros.isEmpty ? nil : Fmt.plata(store.totalMeDeben),
                accionTitulo: cobros.isEmpty ? nil : "+ Presté plata",
                accion: { mostrarPrestamo = true }
            )

            if cobros.isEmpty {
                EstadoVacio(
                    simbolo: "hand.thumbsup",
                    titulo: "Nadie te debe plata",
                    mensaje: "Si le prestas a alguien, anótalo aquí y no se te olvida cobrar.",
                    accionTitulo: "Presté plata",
                    accion: { mostrarPrestamo = true }
                )
                .background(FondoTarjeta())
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(cobros.enumerated()), id: \.element.id) { indice, cobro in
                        if indice > 0 { SeparadorFila(sangria: Espacio.m) }
                        FilaCobroBalance(
                            cobro: cobro,
                            abonos: store.data.agenda.filter { $0.cobroId == cobro.id },
                            alCobrar: { pedirCobro(cobro) },
                            alEditar: { edicion = .agenda(cobro.id) }
                        )
                    }
                }
                .panel(padding: 0)
            }
        }
    }

    private func pedirCobro(_ cobro: AgendaItem) {
        solicitud = SolicitudValor(
            titulo: cobro.persona ?? cobro.nombre,
            pregunta: "¿Cuánto te pagó?",
            montoSugerido: cobro.monto
        ) { monto, fecha in
            let pendiente = store.data.agenda.first(where: { $0.id == cobro.id })?.monto ?? cobro.monto
            store.registrarCobro(cobro, monto: monto, fecha: fecha)

            if monto.redondeado >= pendiente {
                // Pagó todo: el cobro quedó hecho.
                if let actual = store.data.agenda.first(where: { $0.id == cobro.id }), actual.hecho {
                    ofrecerDeshacer { store.deshacerAgenda(actual) }
                }
            } else if let abono = store.data.agenda.last(where: { $0.cobroId == cobro.id }) {
                // Abono parcial: borrar el abono devuelve el saldo al cobro.
                ofrecerDeshacer { store.quitarAgenda(abono) }
            }
        }
    }

    // MARK: Lo que debo

    private var debo: some View {
        let deudas = deudasOrdenadas
        return VStack(alignment: .leading, spacing: Espacio.titulo) {
            EncabezadoSeccion(
                titulo: "Lo que debo",
                detalle: deudas.isEmpty ? nil : Fmt.plata(store.totalDebo),
                accionTitulo: deudas.isEmpty ? nil : "+ Nueva deuda",
                accion: { mostrarDeuda = true }
            )

            if deudas.isEmpty {
                EstadoVacio(
                    simbolo: "checkmark.seal",
                    titulo: "No debes nada",
                    mensaje: "Si tienes una tarjeta, un crédito o le debes a alguien, agrégalo para ver cómo baja.",
                    accionTitulo: "Agregar una deuda",
                    accion: { mostrarDeuda = true }
                )
                .background(FondoTarjeta())
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(deudas.enumerated()), id: \.element.id) { indice, deuda in
                        if indice > 0 { SeparadorFila(sangria: Espacio.m) }
                        FilaDeudaBalance(
                            deuda: deuda,
                            abonos: store.data.agenda.filter { $0.abono && $0.hecho && $0.deudaId == deuda.id },
                            alAbonar: { pedirAbono(deuda) },
                            alEditar: { edicion = .deuda(deuda.id) },
                            alBorrar: {
                                Haptics.warning()
                                borrandoDeuda = deuda
                            }
                        )
                    }
                }
                .panel(padding: 0)
            }
        }
    }

    private func pedirAbono(_ deuda: Deuda) {
        solicitud = SolicitudValor(
            titulo: deuda.nombre,
            pregunta: "¿Cuánto abonas?",
            montoSugerido: deuda.cuota ?? deuda.saldo
        ) { monto, fecha in
            let saldoAntes = store.deuda(deuda.id)?.saldo ?? deuda.saldo
            store.abonarDeuda(deuda, monto: monto, fecha: fecha)
            // Borrar el abono devuelve el saldo exacto, salvo que el abono pasara el saldo.
            if monto.redondeado <= saldoAntes,
               let abono = store.data.agenda.last(where: { $0.abono && $0.deudaId == deuda.id }) {
                ofrecerDeshacer { store.quitarAgenda(abono) }
            }
        }
    }
}

// MARK: - Tarjeta de cajita

/// Cajita como tarjeta: nombre, cifra guardada con barra de avance, "Guardar plata" y menú con Sacar / Borrar.
private struct TarjetaCajitaBalance: View {
    let cajita: Cajita
    var para: String?
    var alGuardar: () -> Void
    var alSacar: () -> Void
    var alEditar: () -> Void
    var alBorrar: () -> Void

    private var estado: String {
        if cajita.completa { return "¡Completa!" }
        if cajita.meta <= 0 { return "Sin meta" }
        return "Faltan \(Fmt.plata(cajita.falta))"
    }

    /// "Para Arriendo · nota": siempre ocupa dos líneas para que las tarjetas vecinas queden parejas.
    private var subtitulo: String {
        var partes: [String] = []
        if let para { partes.append("Para \(para)") }
        if !cajita.nota.isEmpty { partes.append(cajita.nota) }
        return partes.isEmpty ? (cajita.meta > 0 ? "Meta de \(Fmt.plata(cajita.meta))" : "Plata apartada") : partes.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.s) {
            HStack(alignment: .firstTextBaseline, spacing: Espacio.xs) {
                Text(cajita.nombre)
                    .font(.headline)
                    .foregroundStyle(Theme.texto)
                    .lineLimit(2)
                Spacer(minLength: 0)
                MenuMas(etiqueta: "Más opciones de \(cajita.nombre)") {
                    Button(action: alEditar) {
                        Label("Editar cajita", systemImage: "pencil")
                    }
                    Button(action: alSacar) {
                        Label("Sacar plata", systemImage: "arrow.uturn.up")
                    }
                    .disabled(cajita.guardado <= 0)
                    Button(role: .destructive, action: alBorrar) {
                        Label("Borrar cajita", systemImage: "trash")
                    }
                }
                .padding(.trailing, -Espacio.xs)
                .padding(.vertical, -Espacio.xs)
            }

            Text(subtitulo)
                .font(.footnote)
                .foregroundStyle(Theme.gris)
                .lineLimit(2)
                .padding(.top, -Espacio.xs)

            VStack(alignment: .leading, spacing: 6) {
                CifraPlata(valor: cajita.guardado, estilo: .media, signo: .ninguno)
                if cajita.meta > 0 {
                    BarraProgreso(avance: cajita.avance, color: cajita.completa ? Theme.verde : cajita.color,
                                  alto: 6, etiqueta: "Avance de \(cajita.nombre)")
                }
                HStack(spacing: 4) {
                    if cajita.completa {
                        Image(systemName: "checkmark.circle.fill")
                            .accessibilityHidden(true)
                        Text(estado)
                    } else if cajita.meta > 0 {
                        Text("de \(Fmt.plata(cajita.meta))")
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: Espacio.xxs)
                        Text("\(Int((cajita.avance * 100).rounded())) %")
                    } else {
                        Text(estado)
                    }
                }
                .font(.footnote.weight(cajita.completa ? .semibold : .regular))
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(cajita.completa ? Theme.verde : Theme.gris)
            }

            Spacer(minLength: 0)

            Button(action: alGuardar) {
                Label("Guardar plata", systemImage: "plus")
            }
            .buttonStyle(.secundario(Theme.acento, anchoCompleto: true))
            .accessibilityLabel("Guardar plata en \(cajita.nombre)")
        }
        .padding(Espacio.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FondoTarjeta())
        .contentShape(Rectangle())
        .onTapGesture(perform: alEditar)
        .contextMenu {
            Button(action: alEditar) {
                Label("Editar cajita", systemImage: "pencil")
            }
            Button(action: alGuardar) {
                Label("Guardar plata", systemImage: "plus")
            }
            Button(action: alSacar) {
                Label("Sacar plata", systemImage: "arrow.uturn.up")
            }
            .disabled(cajita.guardado <= 0)
            Button(role: .destructive, action: alBorrar) {
                Label("Borrar cajita", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(cajita.nombre): \(CifraPlata.textoAccesible(cajita.guardado, signo: .ninguno))"
                            + (cajita.meta > 0 ? " de \(CifraPlata.textoAccesible(cajita.meta, signo: .ninguno))" : "")
                            + ". \(estado)")
        .accessibilityAction(named: "Editar", alEditar)
    }
}

// MARK: - Fila de cobro (me deben)

/// Persona que te debe: saldo pendiente, avance de lo que ya te pagó y "Me pagó".
private struct FilaCobroBalance: View {
    let cobro: AgendaItem
    let abonos: [AgendaItem]
    var alCobrar: () -> Void
    var alEditar: () -> Void

    private var original: Decimal { max(cobro.montoOriginal ?? cobro.monto, cobro.monto) }
    private var abonado: Decimal { max(0, original - cobro.monto) }
    private var avance: Double { original > 0 ? abonado.doble / original.doble : 0 }

    private var subtitulo: String {
        var texto = "Prestaste \(Fmt.plata(cobro.montoOriginal ?? cobro.monto))"
        if let nota = cobro.nota, !nota.isEmpty { texto += " · \(nota)" }
        return texto
    }

    private var vencido: Bool {
        guard let fecha = cobro.fecha else { return false }
        return fecha < Date().inicioDeDia
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.s) {
            HStack(alignment: .top, spacing: Espacio.s) {
                IconoCuadro(simbolo: cobro.simbolo, color: Theme.verde, lado: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(cobro.persona ?? cobro.nombre)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.texto)
                        .lineLimit(2)
                    Text(subtitulo)
                        .font(.subheadline)
                        .foregroundStyle(Theme.gris)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 2) {
                    CifraPlata(valor: cobro.monto, estilo: .normal, signo: .ninguno)
                    Text("por cobrar")
                        .font(.footnote)
                        .foregroundStyle(Theme.gris)
                }
                .layoutPriority(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAction(named: "Editar", alEditar)
            .contentShape(Rectangle())
            .onTapGesture(perform: alEditar)

            if abonado > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    BarraProgreso(avance: avance, color: Theme.verde, alto: 8,
                                  etiqueta: "Lo que ya te pagó \(cobro.persona ?? cobro.nombre)")
                    Text("Ya te pagó \(Fmt.plata(abonado))"
                         + (abonos.isEmpty ? "" : " en \(abonos.count) \(abonos.count == 1 ? "abono" : "abonos")"))
                        .font(.footnote)
                        .foregroundStyle(Theme.gris)
                }
            }

            HStack(spacing: Espacio.xs) {
                Button(action: alCobrar) {
                    Label("Me pagó", systemImage: "checkmark")
                }
                .buttonStyle(.secundario(Theme.verde))
                .accessibilityLabel("Me pagó \(cobro.persona ?? cobro.nombre)")

                Spacer(minLength: 0)

                if let fecha = cobro.fecha {
                    Insignia(texto: (vencido ? "Debía pagarte el " : "Te paga el ") + Fmt.diaYMes(fecha),
                             tono: vencido ? .negativo : .neutro,
                             simbolo: "calendar")
                } else if let fechaTexto = cobro.fechaTexto?.fechaSinTilde, !fechaTexto.isEmpty {
                    Insignia(texto: fechaTexto, tono: .neutro, simbolo: "calendar")
                }
            }
        }
        .padding(Espacio.m)
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: alCobrar) {
                Label("Me pagó", systemImage: "checkmark.circle")
            }
            Button(action: alEditar) {
                Label("Editar o borrar", systemImage: "pencil")
            }
        }
    }
}

// MARK: - Fila de deuda (lo que debo)

/// Deuda con saldo, avance de lo pagado, abonos y "Abonar" (o "Borrar" cuando ya está pagada).
private struct FilaDeudaBalance: View {
    let deuda: Deuda
    let abonos: [AgendaItem]
    var alAbonar: () -> Void
    var alEditar: () -> Void
    var alBorrar: () -> Void

    private var ultimoAbono: AgendaItem? {
        abonos.max(by: { ($0.hechoFecha ?? $0.creado) < ($1.hechoFecha ?? $1.creado) })
    }

    private var detalleAbonos: String? {
        guard let ultimo = ultimoAbono else { return nil }
        let cuantos = "\(abonos.count) \(abonos.count == 1 ? "abono" : "abonos")"
        let fecha = Fmt.diaYMes(ultimo.hechoFecha ?? ultimo.creado)
        return "\(cuantos) · el último de \(Fmt.plata(ultimo.valorEfectivo)) el \(fecha)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.s) {
            HStack(alignment: .top, spacing: Espacio.s) {
                IconoCuadro(simbolo: deuda.pagada ? "checkmark.seal.fill" : "creditcard.fill",
                            color: deuda.pagada ? Theme.verde : Theme.acento,
                            lado: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(deuda.nombre)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.texto)
                        .lineLimit(2)
                    if !deuda.nota.isEmpty {
                        Text(deuda.nota)
                            .font(.subheadline)
                            .foregroundStyle(Theme.gris)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if deuda.pagada {
                    Insignia(texto: "Pagada", tono: .positivo, simbolo: "checkmark")
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        CifraPlata(valor: deuda.saldo, estilo: .normal, signo: .ninguno)
                        Text("te falta")
                            .font(.footnote)
                            .foregroundStyle(Theme.gris)
                    }
                    .layoutPriority(1)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAction(named: "Editar", alEditar)
            .contentShape(Rectangle())
            .onTapGesture(perform: alEditar)

            VStack(alignment: .leading, spacing: 6) {
                BarraProgreso(avance: deuda.avance,
                              color: deuda.pagada ? Theme.verde : Theme.acento,
                              alto: 8,
                              etiqueta: "Lo pagado de \(deuda.nombre)")
                Text("Llevas \(Fmt.plata(deuda.pagado)) de \(Fmt.plata(deuda.original))"
                     + (deuda.cuota.map { " · cuota de \(Fmt.plata($0))" } ?? ""))
                    .font(.footnote)
                    .foregroundStyle(Theme.gris)
                    .fixedSize(horizontal: false, vertical: true)
                if let detalleAbonos {
                    Text(detalleAbonos)
                        .font(.footnote)
                        .foregroundStyle(Theme.gris)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let valorBien = deuda.valorBien, valorBien > 0 {
                    Text("Lo que pagas vale \(Fmt.plata(valorBien))")
                        .font(.footnote)
                        .foregroundStyle(Theme.gris)
                }
            }

            HStack(spacing: Espacio.xs) {
                if deuda.pagada {
                    Text("¡Terminaste de pagarla!")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.verde)
                    Spacer(minLength: 0)
                } else {
                    Button(action: alAbonar) {
                        Label("Abonar", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.secundario)
                    .accessibilityLabel("Abonar a \(deuda.nombre)")
                    Spacer(minLength: 0)
                }
                MenuMas(etiqueta: "Más opciones de \(deuda.nombre)") {
                    menuDeuda
                }
                .padding(.trailing, -Espacio.xs)
            }
        }
        .padding(Espacio.m)
        .contentShape(Rectangle())
        .contextMenu {
            menuDeuda
        }
    }

    @ViewBuilder
    private var menuDeuda: some View {
        if !deuda.pagada {
            Button(action: alAbonar) {
                Label("Abonar", systemImage: "arrow.down.circle")
            }
        }
        Button(action: alEditar) {
            Label("Editar deuda", systemImage: "pencil")
        }
        Button(role: .destructive, action: alBorrar) {
            Label("Borrar deuda", systemImage: "trash")
        }
    }
}

// MARK: - Nueva cajita

/// Hoja "Nueva cajita": nombre y meta (opcional).
private struct HojaNuevaCajitaBalance: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var cerrar

    @State private var nombre = ""
    @State private var meta = ""
    @FocusState private var nombreEnfocado: Bool

    private var nombreLimpio: String { nombre.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Viaje, matrícula, emergencias…", text: $nombre)
                        .textInputAutocapitalization(.sentences)
                        .focused($nombreEnfocado)
                        .submitLabel(.next)
                        .accessibilityLabel("Nombre de la cajita")
                } header: {
                    Text("¿Para qué es?")
                }
                .listRowBackground(Theme.superficie)

                Section {
                    VStack(spacing: Espacio.xs) {
                        Text("Meta")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.gris)
                        CampoPlata(texto: $meta, grande: true, alineacion: .center,
                                   etiqueta: "Meta de la cajita")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Espacio.s)
                } footer: {
                    Text("Opcional. Con una meta ves cuánto te falta.")
                        .font(.footnote)
                }
                .listRowBackground(Theme.superficie)

                Section {
                    Button("Crear cajita") { crear() }
                        .buttonStyle(.principal)
                        .disabled(nombreLimpio.isEmpty)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.fondo.ignoresSafeArea())
            .navigationTitle("Nueva cajita")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") { crear() }
                        .fontWeight(.semibold)
                        .disabled(nombreLimpio.isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { nombreEnfocado = true }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func crear() {
        guard !nombreLimpio.isEmpty else { return }
        store.crearCajita(nombre: nombreLimpio, meta: Fmt.leerPlata(meta) ?? 0)
        cerrar()
    }
}

// MARK: - Presté plata

/// "Presté plata": registra la salida y deja el cobro pendiente.
struct HojaPrestamo: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var cerrar

    @State private var persona = ""
    @State private var texto = ""
    @State private var nota = ""
    @State private var fecha = Date()
    @State private var conPlazo = false
    @State private var plazo = Date()

    private var listo: Bool {
        !persona.trimmingCharacters(in: .whitespaces).isEmpty && Fmt.leerPlata(texto) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: Espacio.xs) {
                        Text("¿Cuánto prestaste?")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.gris)
                        CampoPlata(texto: $texto, grande: true, alineacion: .center,
                                   etiqueta: "Cuánto prestaste", enfocarAlAparecer: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Espacio.m)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: Espacio.xs, leading: 0, bottom: Espacio.xs, trailing: 0))

                Section {
                    TextField("Nombre", text: $persona)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("A quién le prestaste")
                    DatePicker("Se lo di el", selection: $fecha, displayedComponents: .date)
                        .environment(\.locale, Fmt.locale)
                } header: {
                    Text("¿A quién?")
                }
                .listRowBackground(Theme.superficie)

                Section {
                    Toggle("Tiene fecha", isOn: $conPlazo.animation(.spring(response: 0.35, dampingFraction: 0.85)))
                        .tint(Theme.acento)
                    if conPlazo {
                        DatePicker("Te paga el", selection: $plazo, displayedComponents: .date)
                            .environment(\.locale, Fmt.locale)
                    }
                } header: {
                    Text("¿Cuándo te paga?")
                }
                .listRowBackground(Theme.superficie)

                Section {
                    TextField("Opcional", text: $nota)
                        .accessibilityLabel("Nota")
                } header: {
                    Text("Nota")
                } footer: {
                    Text("La plata sale de tu plata libre y queda en \"Me deben\" hasta que te pague.")
                        .font(.footnote)
                }
                .listRowBackground(Theme.superficie)

                Section {
                    Button("Guardar préstamo") { guardar() }
                        .buttonStyle(.principal)
                        .disabled(!listo)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.fondo.ignoresSafeArea())
            .navigationTitle("Presté plata")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardar() }
                        .fontWeight(.semibold)
                        .disabled(!listo)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func guardar() {
        if let monto = Fmt.leerPlata(texto) {
            store.prestarPlata(
                persona: persona.trimmingCharacters(in: .whitespaces),
                monto: monto,
                fecha: fecha,
                cuandoPaga: conPlazo ? plazo : nil,
                nota: nota
            )
        }
        cerrar()
    }
}

// MARK: - Nueva deuda

struct HojaNuevaDeuda: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var cerrar

    @State private var nombre = ""
    @State private var saldo = ""
    @State private var cuota = ""
    @State private var nota = ""

    private var listo: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty && Fmt.leerPlata(saldo) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: Espacio.xs) {
                        Text("¿Cuánto debes hoy?")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.gris)
                        CampoPlata(texto: $saldo, grande: true, alineacion: .center,
                                   etiqueta: "Saldo de la deuda", enfocarAlAparecer: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Espacio.m)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: Espacio.xs, leading: 0, bottom: Espacio.xs, trailing: 0))

                Section {
                    TextField("Banco, tarjeta, persona…", text: $nombre)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("A quién le debes")
                } header: {
                    Text("¿A quién le debes?")
                }
                .listRowBackground(Theme.superficie)

                Section {
                    HStack {
                        Text("Cuota")
                            .foregroundStyle(Theme.texto)
                        CampoPlata(texto: $cuota, alineacion: .trailing, etiqueta: "Cuota mensual")
                    }
                    TextField("Nota (opcional)", text: $nota)
                        .accessibilityLabel("Nota")
                } header: {
                    Text("Opcional")
                } footer: {
                    Text("Con la cuota te sugiero cuánto abonar cada vez.")
                        .font(.footnote)
                }
                .listRowBackground(Theme.superficie)

                Section {
                    Button("Agregar deuda") { guardar() }
                        .buttonStyle(.principal)
                        .disabled(!listo)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.fondo.ignoresSafeArea())
            .navigationTitle("Nueva deuda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Agregar") { guardar() }
                        .fontWeight(.semibold)
                        .disabled(!listo)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func guardar() {
        if let valor = Fmt.leerPlata(saldo) {
            store.agregarDeuda(
                nombre: nombre.trimmingCharacters(in: .whitespaces),
                saldo: valor,
                cuota: Fmt.leerPlata(cuota),
                nota: nota
            )
        }
        cerrar()
    }
}
