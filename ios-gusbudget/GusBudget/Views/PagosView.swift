import SwiftUI

/// Pagos e ingresos esperados (sección 2.4).
/// Lista nativa agrupada por urgencia: desliza a la derecha para "Ya pagué" / "Ya me llegó"
/// y a la izquierda para borrar. Mantener presionado muestra las mismas acciones.
struct PagosView: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.ofrecerDeshacer) private var ofrecerDeshacer

    @State private var solicitud: SolicitudValor?
    @State private var mostrarFormulario = false
    @State private var quitando: Obligacion?
    /// "Ya hecho" sobre el que se abrió el menú de acciones (deshacer o borrar).
    @State private var hechoElegido: AgendaItem?
    @State private var verTodosHechos = false

    /// Cuántos "ya hechos" se ven antes de tocar "Ver todos".
    private let hechosVisibles = 5

    private var pendientes: [Obligacion] {
        // Lo que le deben a él se maneja en Balance, no aquí.
        store.obligaciones().filter { !$0.porCobrar }
    }

    struct GrupoObligaciones: Identifiable {
        let estado: EstadoObligacion
        let lista: [Obligacion]
        var id: String { estado.rawValue }
        var total: Decimal { lista.reduce(Decimal.zero) { $0 + $1.monto } }
        var totalPagos: Decimal {
            lista.filter { $0.tipo == .pago }.reduce(Decimal.zero) { $0 + $1.monto }
        }
        var totalIngresos: Decimal {
            lista.filter { $0.tipo == .ingreso }.reduce(Decimal.zero) { $0 + $1.monto }
        }
    }

    private func agrupar(_ pendientes: [Obligacion]) -> [GrupoObligaciones] {
        let orden: [EstadoObligacion] = [.vencido, .pronto, .mes, .despues, .sinFecha]
        return orden.compactMap { estado -> GrupoObligaciones? in
            let lista = pendientes.filter { $0.estado == estado }
            return lista.isEmpty ? nil : GrupoObligaciones(estado: estado, lista: lista)
        }
    }

    var body: some View {
        let pendientes = self.pendientes
        let grupos = agrupar(pendientes)
        let hechos = store.yaHechos()

        NavigationStack {
            List {
                // Resumen (o estado vacío)
                Section {
                    if pendientes.isEmpty {
                        EstadoVacio(
                            simbolo: "checkmark.seal",
                            titulo: "Estás al día",
                            mensaje: "No tienes pagos pendientes. Agrega uno y te lo recuerdo a tiempo.",
                            accionTitulo: "+ Nuevo pago",
                            accion: { mostrarFormulario = true }
                        )
                        .background(FondoTarjeta())
                    } else {
                        resumen(pendientes)
                    }
                }
                .listRowInsets(EdgeInsets(top: Espacio.xxs, leading: 0, bottom: Espacio.xs, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                // Grupos por urgencia
                ForEach(grupos) { grupo in
                    Section {
                        ForEach(grupo.lista) { obligacion in
                            FilaObligacion(
                                obligacion: obligacion,
                                alHacer: { solicitud = solicitudPago(obligacion) },
                                alQuitar: accionBorrar(obligacion)
                            )
                            .listRowBackground(Theme.superficie)
                            .listRowSeparatorTint(Theme.linea)
                        }
                    } header: {
                        EncabezadoGrupoPagos(
                            titulo: titulo(de: grupo.estado),
                            detalle: detalle(de: grupo),
                            accionTitulo: grupo.id == grupos.first?.id ? "+ Nuevo pago" : nil,
                            accion: { mostrarFormulario = true }
                        )
                    }
                }

                // Agregar
                if !pendientes.isEmpty {
                    Section {
                        Button {
                            mostrarFormulario = true
                        } label: {
                            Label("Nuevo pago o ingreso", systemImage: "plus.circle.fill")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Theme.acento)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .listRowBackground(Theme.superficie)
                    } footer: {
                        Text("Desliza un pago a la derecha para marcarlo como hecho, o a la izquierda para borrarlo.")
                            .font(.footnote)
                            .foregroundStyle(Theme.gris)
                    }
                }

                // Ya hechos
                if !hechos.isEmpty {
                    Section {
                        let mostrados = verTodosHechos ? hechos : Array(hechos.prefix(hechosVisibles))
                        ForEach(mostrados) { item in
                            filaHecho(item)
                                .listRowBackground(Theme.superficie)
                                .listRowSeparatorTint(Theme.linea)
                        }
                        if hechos.count > hechosVisibles {
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    verTodosHechos.toggle()
                                }
                            } label: {
                                HStack {
                                    Text(verTodosHechos ? "Ver menos" : "Ver los \(hechos.count)")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Image(systemName: verTodosHechos ? "chevron.up" : "chevron.down")
                                        .font(.footnote.weight(.semibold))
                                        .accessibilityHidden(true)
                                }
                                .foregroundStyle(Theme.acento)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .listRowBackground(Theme.superficie)
                        }
                    } header: {
                        EncabezadoGrupoPagos(
                            titulo: "Ya hechos",
                            detalle: "Los últimos \(hechos.count)"
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .environment(\.tarjetasSinSombra, true)
            .fondoPantalla()
            .navigationTitle("Pagos")
            .navigationBarTitleDisplayMode(.large)
            .conBotonAjustes()
            .sheet(item: $solicitud) { peticion in
                HojaValorReal(solicitud: peticion)
            }
            .sheet(isPresented: $mostrarFormulario) {
                HojaNuevoPago().environmentObject(store)
            }
            .confirmationDialog(
                "¿Borrar \(quitando?.nombre ?? "")?",
                isPresented: Binding(get: { quitando != nil }, set: { if !$0 { quitando = nil } }),
                titleVisibility: .visible
            ) {
                Button("Borrar", role: .destructive) {
                    if let quitando { store.quitar(quitando) }
                    quitando = nil
                }
                Button("Cancelar", role: .cancel) { quitando = nil }
            } message: {
                Text("Sale de tus pagos pendientes.")
            }
        }
        .confirmationDialog(
            hechoElegido?.nombre ?? "",
            isPresented: Binding(get: { hechoElegido != nil }, set: { if !$0 { hechoElegido = nil } }),
            titleVisibility: .visible
        ) {
            if let item = hechoElegido {
                if seBorra(item) {
                    Button("Borrar", role: .destructive) {
                        store.quitarAgenda(item)
                        hechoElegido = nil
                    }
                } else {
                    Button(item.tipo == .ingreso ? "Deshacer: todavía no me llegó" : "Deshacer: todavía no lo pagué") {
                        deshacerHecho(item)
                        hechoElegido = nil
                    }
                }
            }
            Button("Cancelar", role: .cancel) { hechoElegido = nil }
        } message: {
            if let item = hechoElegido {
                Text(seBorra(item)
                     ? "Se borra este movimiento de tus cuentas."
                     : "Vuelve a la lista de pendientes.")
            }
        }
    }

    // MARK: Resumen

    private func resumen(_ pendientes: [Obligacion]) -> some View {
        let pagos = pendientes.filter { $0.tipo == .pago }
        let totalPagos = pagos.reduce(Decimal.zero) { $0 + $1.monto }
        let atrasado = pagos.filter { $0.estado == .vencido }.reduce(Decimal.zero) { $0 + $1.monto }
        let semana = pagos.filter { $0.estado == .pronto }.reduce(Decimal.zero) { $0 + $1.monto }
        let porRecibir = pendientes.filter { $0.tipo == .ingreso }.reduce(Decimal.zero) { $0 + $1.monto }
        let vencidos = pagos.filter { $0.estado == .vencido }.count

        var contexto = pagos.isEmpty
            ? "Estás al día con tus pagos"
            : "\(pagos.count) \(pagos.count == 1 ? "pago pendiente" : "pagos pendientes")"
        if vencidos > 0 {
            contexto += " · \(vencidos) \(vencidos == 1 ? "atrasado" : "atrasados")"
        }

        return TarjetaHero(espaciado: Espacio.s) {
            Text("Por pagar")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.gris)
            CifraPlata(valor: totalPagos, estilo: .hero, signo: .ninguno, color: .white)
            Text(contexto)
                .font(.subheadline)
                .foregroundStyle(Theme.gris)
            ResumenDatos(
                datos: [
                    DatoResumen(titulo: "Atrasado", valor: atrasado, signo: .ninguno,
                                color: atrasado > 0 ? Theme.rojo : nil),
                    DatoResumen(titulo: "Próximos 7 días", valor: semana, signo: .ninguno),
                    DatoResumen(titulo: "Te debe llegar", valor: porRecibir,
                                signo: porRecibir > 0 ? .entrada : .ninguno,
                                color: porRecibir > 0 ? Theme.verde : nil)
                ],
                sobreOscuro: true
            )
            .padding(.top, Espacio.xxs)
        }
    }

    // MARK: Grupos

    private func titulo(de estado: EstadoObligacion) -> String {
        switch estado {
        case .vencido: return "Atrasados"
        case .pronto: return "Esta semana"
        case .mes: return "Resto del mes"
        case .despues: return "Más adelante"
        case .sinFecha: return "Sin fecha"
        }
    }

    private func color(de estado: EstadoObligacion) -> Color {
        switch estado {
        case .vencido: return Theme.rojo
        case .pronto: return Theme.ambar
        case .mes: return Theme.acento
        case .despues, .sinFecha: return Theme.gris
        }
    }

    private func detalle(de grupo: GrupoObligaciones) -> String {
        var partes: [String] = []
        if grupo.totalPagos > 0 { partes.append("Sale \(Fmt.plata(grupo.totalPagos))") }
        if grupo.totalIngresos > 0 { partes.append("Entra \(Fmt.plata(grupo.totalIngresos))") }
        return partes.joined(separator: " · ")
    }

    // MARK: Ya hechos

    /// Extras y abonos se borran; lo demás se deshace (vuelve a pendiente).
    private func seBorra(_ item: AgendaItem) -> Bool {
        item.seBorraEnVezDeDeshacer
    }

    private func filaHecho(_ item: AgendaItem) -> some View {
        let esIngreso = item.tipo == .ingreso
        let fecha = Fmt.fechaCorta(item.hechoFecha ?? item.creado)
        return Button {
            hechoElegido = item
        } label: {
            HStack(spacing: Espacio.s) {
                IconoCuadro(simbolo: item.simbolo, color: esIngreso ? Theme.verde : Theme.acento, lado: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.nombre)
                        .font(.body)
                        .foregroundStyle(Theme.texto)
                        .lineLimit(2)
                    Text((esIngreso ? "Llegó · " : "Pagado · ") + fecha)
                        .font(.subheadline)
                        .foregroundStyle(Theme.gris)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                CifraPlata(valor: item.valorEfectivo, estilo: .normal,
                           signo: esIngreso ? .entrada : .salida)
                    .layoutPriority(1)
            }
            .padding(.vertical, Espacio.xxs)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.presionable)
        .accessibilityElement(children: .combine)
        .accessibilityHint(seBorra(item) ? "Toca para borrarlo" : "Toca para deshacerlo")
        .contextMenu {
            if seBorra(item) {
                Button(role: .destructive) {
                    hechoElegido = item
                } label: {
                    Label("Borrar", systemImage: "trash")
                }
            } else {
                Button {
                    deshacerHecho(item)
                } label: {
                    Label("Deshacer", systemImage: "arrow.uturn.backward")
                }
            }
        }
        .swipeActions(edge: .trailing) {
            if seBorra(item) {
                Button(role: .destructive) {
                    Haptics.warning()
                    hechoElegido = item
                } label: {
                    Label("Borrar", systemImage: "trash")
                }
            } else {
                Button {
                    deshacerHecho(item)
                } label: {
                    Label("Deshacer", systemImage: "arrow.uturn.backward")
                }
                .tint(Theme.ambarRelleno)
            }
        }
    }

    // MARK: Acciones

    /// Solo lo que viene de la agenda se puede borrar (los fijos se manejan en Presupuesto).
    private func accionBorrar(_ obligacion: Obligacion) -> (() -> Void)? {
        guard obligacion.agendaId != nil else { return nil }
        return {
            Haptics.warning()
            quitando = obligacion
        }
    }

    /// Hoja "¿Cuánto pagaste de verdad?" que, al guardar, ofrece deshacer.
    private func solicitudPago(_ obligacion: Obligacion) -> SolicitudValor {
        SolicitudValor(
            titulo: obligacion.nombre,
            pregunta: obligacion.tipo == .pago ? "¿Cuánto pagaste de verdad?" : "¿Cuánto te llegó?",
            montoSugerido: obligacion.monto,
            fechaSugerida: Date()
        ) { monto, fecha in
            registrarConDeshacer(obligacion, monto: monto, fecha: fecha)
        }
    }

    private func registrarConDeshacer(_ obligacion: Obligacion, monto: Decimal, fecha: Date) {
        store.registrar(obligacion, monto: monto, fecha: fecha)

        if let fijoId = obligacion.fijoId, let periodo = obligacion.periodo {
            let id = "\(fijoId)_\(periodo)"
            if let pago = store.data.pagosFijos.first(where: { $0.id == id }) {
                ofrecerDeshacer { store.deshacerPagoFijo(pago) }
            }
        } else if let agendaId = obligacion.agendaId,
                  let item = store.data.agenda.first(where: { $0.id == agendaId }),
                  item.hecho, !item.porCobrar {
            ofrecerDeshacer { store.deshacerAgenda(item) }
        }
    }

    /// Vuelve a dejar pendiente un "ya hecho" y ofrece rehacerlo con el mismo valor y fecha.
    private func deshacerHecho(_ item: AgendaItem) {
        let monto = item.hechoMonto ?? item.monto
        let fecha = item.hechoFecha ?? Date()
        store.deshacerAgenda(item)
        ofrecerDeshacer {
            if let actual = store.data.agenda.first(where: { $0.id == item.id }), !actual.hecho {
                store.marcarHecho(actual, monto: monto, fecha: fecha)
            }
        }
    }
}

// MARK: - Encabezado de grupo

/// El mismo encabezado de sección de Inicio y Balance (título + detalle), dentro de una `List`.
private struct EncabezadoGrupoPagos: View {
    let titulo: String
    var detalle: String = ""
    var accionTitulo: String?
    var accion: (() -> Void)?

    var body: some View {
        EncabezadoSeccion(
            titulo: titulo,
            detalle: detalle.isEmpty ? nil : detalle,
            accionTitulo: accionTitulo,
            accion: accion
        )
        .textCase(nil)
        // Alinea con el borde de las tarjetas, como en Inicio y Balance.
        .padding(.horizontal, -Espacio.m)
        .padding(.top, Espacio.xs)
        .padding(.bottom, Espacio.xxs)
    }
}

// MARK: - Nuevo pago o ingreso

/// Formulario "Nuevo pago" / "Nuevo ingreso": cifra grande arriba, nombre y fecha.
struct HojaNuevoPago: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var cerrar

    @State private var tipo: TipoAgenda = .pago
    @State private var nombre = ""
    @State private var texto = ""
    @State private var conFecha = true
    @State private var fecha = Date()

    private var nombreLimpio: String { nombre.trimmingCharacters(in: .whitespaces) }
    private var listo: Bool { !nombreLimpio.isEmpty && Fmt.leerPlata(texto) != nil }
    private var esPago: Bool { tipo == .pago }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tipo", selection: $tipo) {
                        Text("Pago").tag(TipoAgenda.pago)
                        Text("Ingreso").tag(TipoAgenda.ingreso)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Tipo")

                    VStack(spacing: Espacio.xs) {
                        Text(esPago ? "¿Cuánto vas a pagar?" : "¿Cuánto te va a llegar?")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.gris)
                        CampoPlata(texto: $texto, grande: true, alineacion: .center,
                                   etiqueta: esPago ? "Valor del pago" : "Valor del ingreso",
                                   enfocarAlAparecer: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Espacio.m)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: Espacio.xs, leading: 0, bottom: Espacio.xs, trailing: 0))

                Section {
                    TextField(esPago ? "Arriendo, matrícula…" : "Sueldo, venta…", text: $nombre)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .accessibilityLabel(esPago ? "Nombre del pago" : "Nombre del ingreso")
                } header: {
                    Text("¿Qué es?")
                }
                .listRowBackground(Theme.superficie)

                Section {
                    Toggle("Tiene fecha", isOn: $conFecha.animation(.spring(response: 0.35, dampingFraction: 0.85)))
                        .tint(Theme.acento)
                    if conFecha {
                        DatePicker("Fecha", selection: $fecha, displayedComponents: .date)
                            .environment(\.locale, Fmt.locale)
                    }
                } header: {
                    Text("¿Cuándo?")
                } footer: {
                    Text(conFecha
                         ? "Te lo muestro en \"Esta semana\" cuando falten 7 días o menos."
                         : "Queda en \"Sin fecha\" hasta que lo marques.")
                        .font(.footnote)
                }
                .listRowBackground(Theme.superficie)

                Section {
                    Button(esPago ? "Agregar pago" : "Agregar ingreso") {
                        guardar()
                        cerrar()
                    }
                    .buttonStyle(.principal)
                    .disabled(!listo)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.fondo.ignoresSafeArea())
            .navigationTitle(esPago ? "Nuevo pago" : "Nuevo ingreso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Agregar") {
                        guardar()
                        cerrar()
                    }
                    .fontWeight(.semibold)
                    .disabled(!listo)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func guardar() {
        guard let monto = Fmt.leerPlata(texto) else { return }
        store.agregarAgenda(
            AgendaItem(
                tipo: tipo,
                nombre: nombre.trimmingCharacters(in: .whitespaces),
                monto: monto,
                fecha: conFecha ? fecha : nil,
                simbolo: tipo == .pago ? "calendar" : "arrow.down.circle.fill"
            )
        )
    }
}

// MARK: - Qué se borra y qué se deshace

extension AgendaItem {
    /// Extras, abonos (a cobros o a deudas) y préstamos hechos no son cuentas por pagar:
    /// "deshacerlos" los dejaría como pendientes en Pagos. Se borran, y el store devuelve
    /// el saldo de la deuda o del cobro cuando aplica.
    var seBorraEnVezDeDeshacer: Bool {
        extra || cobroId != nil || abono || ajuste || esSalidaDePrestamo
    }

    /// La salida que crea "Presté plata" (no tiene marca propia en el modelo).
    var esSalidaDePrestamo: Bool {
        tipo == .pago && deudaId == nil && simbolo == "arrow.up.circle.fill"
            && nombre.hasPrefix("Préstamo a ")
    }
}
