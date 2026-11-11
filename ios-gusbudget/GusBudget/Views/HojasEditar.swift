import SwiftUI

// MARK: - Qué se está editando

/// Cualquier dato que se ve en la app se puede abrir para editarlo o borrarlo.
///
///     @State private var edicion: EdicionDato?
///     … .hojaEdicion($edicion)
///     Button { edicion = .cajita(cajita.id) } …
enum EdicionDato: Identifiable, Hashable {
    case gasto(UUID)
    case agenda(UUID)
    case pagoFijo(String)
    case fijo(String)
    case categoria(String)
    case cajita(UUID)
    case deuda(String)

    var id: String {
        switch self {
        case .gasto(let id): return "g_\(id.uuidString)"
        case .agenda(let id): return "a_\(id.uuidString)"
        case .pagoFijo(let id): return "p_\(id)"
        case .fijo(let id): return "f_\(id)"
        case .categoria(let id): return "c_\(id)"
        case .cajita(let id): return "k_\(id.uuidString)"
        case .deuda(let id): return "d_\(id)"
        }
    }

    /// Lo que se edita al tocar una obligación pendiente.
    static func de(_ obligacion: Obligacion) -> EdicionDato? {
        if let agendaId = obligacion.agendaId { return .agenda(agendaId) }
        if let fijoId = obligacion.fijoId { return .fijo(fijoId) }
        return nil
    }
}

/// Elige la hoja según el dato. Si el dato ya no existe (se borró), no muestra nada.
struct HojaEdicion: View {
    let edicion: EdicionDato
    @EnvironmentObject private var store: FinanceStore

    var body: some View {
        switch edicion {
        case .gasto(let id):
            if let gasto = store.data.gastos.first(where: { $0.id == id }) {
                HojaGasto(gasto: gasto)
            }
        case .agenda(let id):
            if let item = store.data.agenda.first(where: { $0.id == id }) {
                HojaEditarAgenda(item: item)
            }
        case .pagoFijo(let id):
            if let pago = store.data.pagosFijos.first(where: { $0.id == id }) {
                HojaEditarPagoFijo(pago: pago)
            }
        case .fijo(let id):
            HojaEditarFijo(fijoID: id)
        case .categoria(let id):
            if let categoria = store.data.categorias.first(where: { $0.id == id }) {
                HojaEditarCategoria(categoria: categoria)
            }
        case .cajita(let id):
            if let cajita = store.data.cajitas.first(where: { $0.id == id }) {
                HojaEditarCajita(cajita: cajita)
            }
        case .deuda(let id):
            if let deuda = store.deuda(id) {
                HojaEditarDeuda(deuda: deuda)
            }
        }
    }
}

private struct ModificadorHojaEdicion: ViewModifier {
    @Binding var edicion: EdicionDato?
    @EnvironmentObject private var store: FinanceStore

    func body(content: Content) -> some View {
        content.sheet(item: $edicion) { dato in
            HojaEdicion(edicion: dato).environmentObject(store)
        }
    }
}

extension View {
    /// Presenta la hoja de edición del dato elegido.
    func hojaEdicion(_ edicion: Binding<EdicionDato?>) -> some View {
        modifier(ModificadorHojaEdicion(edicion: edicion))
    }
}

// MARK: - Piezas comunes

/// Marco de las hojas de edición: Form nativo, Cancelar y Guardar en la barra.
private struct MarcoEdicion<Contenido: View>: View {
    let titulo: String
    var puedeGuardar: Bool = true
    var guardar: () -> Void
    @ViewBuilder var contenido: () -> Contenido

    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            Form {
                contenido()
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.fondo.ignoresSafeArea())
            .navigationTitle(titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        guardar()
                        cerrar()
                    }
                    .fontWeight(.semibold)
                    .disabled(!puedeGuardar)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

/// Cifra grande centrada arriba de la hoja.
private struct SeccionCifra: View {
    let pregunta: String
    @Binding var texto: String
    var pie: String?

    var body: some View {
        Section {
            VStack(spacing: Espacio.xs) {
                Text(pregunta)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.gris)
                    .multilineTextAlignment(.center)
                CampoPlata(texto: $texto, grande: true, alineacion: .center, etiqueta: pregunta)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Espacio.s)
        } footer: {
            if let pie {
                Text(pie)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: Espacio.xs, leading: 0, bottom: Espacio.xs, trailing: 0))
    }
}

/// Fila "Título ……… $ valor" con el campo a la derecha.
private struct FilaPlataEditable: View {
    let titulo: String
    @Binding var texto: String
    var marcador: String = "0"

    var body: some View {
        HStack(spacing: Espacio.xs) {
            Text(titulo)
                .foregroundStyle(Theme.texto)
            Spacer(minLength: Espacio.xs)
            CampoPlata(texto: $texto, marcador: marcador, alineacion: .trailing, etiqueta: titulo)
                .frame(maxWidth: 170)
        }
        .listRowBackground(Theme.superficie)
    }
}

/// Fila de solo lectura "Título ……… valor".
private struct FilaDato: View {
    let titulo: String
    let valor: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titulo)
                .foregroundStyle(Theme.gris)
            Spacer(minLength: Espacio.s)
            Text(valor)
                .foregroundStyle(Theme.texto)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .listRowBackground(Theme.superficie)
    }
}

/// Botón rojo "Borrar …" al final de la hoja, con confirmación.
private struct SeccionBorrar: View {
    let titulo: String
    let pregunta: String
    let mensaje: String
    var deshabilitado = false
    var pie: String?
    var accion: () -> Void

    @State private var confirmar = false

    var body: some View {
        Section {
            Button(role: .destructive) {
                Haptics.warning()
                confirmar = true
            } label: {
                Label(titulo, systemImage: "trash")
                    .foregroundStyle(Theme.rojo)
                    .frame(maxWidth: .infinity)
            }
            .disabled(deshabilitado)
            .listRowBackground(Theme.superficie)
            .confirmationDialog(pregunta, isPresented: $confirmar, titleVisibility: .visible) {
                Button(titulo, role: .destructive, action: accion)
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text(mensaje)
            }
        } footer: {
            if let pie { Text(pie) }
        }
    }
}

/// Fila con círculos de color para elegir.
private struct SelectorColor: View {
    @Binding var hex: String
    let opciones: [String]

    private let columnas = [GridItem(.adaptive(minimum: 40), spacing: Espacio.xs)]

    var body: some View {
        LazyVGrid(columns: columnas, spacing: Espacio.xs) {
            ForEach(opciones, id: \.self) { opcion in
                let elegido = opcion.lowercased() == hex.lowercased()
                Button {
                    Haptics.seleccion()
                    hex = opcion
                } label: {
                    Circle()
                        .fill(Color(hex: opcion))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(.white)
                                .opacity(elegido ? 1 : 0)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Theme.texto.opacity(elegido ? 0.35 : 0), lineWidth: 2)
                                .padding(-4)
                        )
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Color \(opcion)")
                .accessibilityAddTraits(elegido ? [.isSelected] : [])
            }
        }
        .padding(.vertical, Espacio.xxs)
        .listRowBackground(Theme.superficie)
    }

    /// Colores de las categorías de la app más los de las nuevas, sin repetir.
    static func paleta(incluyendo actual: String) -> [String] {
        var lista: [String] = []
        for hex in Semilla.categorias.map(\.colorHex) + Color.coloresNuevos + ["2c56e0", actual]
        where !lista.contains(where: { $0.lowercased() == hex.lowercased() }) {
            lista.append(hex)
        }
        return lista
    }
}

private extension String {
    var limpio: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - Pago, ingreso, cobro, abono, extra o saldo inicial

/// Edita cualquier movimiento de la agenda: valor, fecha (también de lo ya hecho), nombre y nota.
struct HojaEditarAgenda: View {
    let item: AgendaItem

    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var cerrar
    @Environment(\.ofrecerDeshacer) private var ofrecerDeshacer

    @State private var cargado = false
    @State private var valor = ""
    @State private var esperado = ""
    @State private var tipo: TipoAgenda = .pago
    @State private var nombre = ""
    @State private var fuente = ""
    @State private var fecha = Date()
    @State private var conFecha = false
    @State private var fechaTexto = ""
    @State private var nota = ""

    private static let prefijoPrestamo = "Préstamo a "

    /// Lo que alguien te debe y todavía no ha terminado de pagar.
    private var esCobro: Bool { item.porCobrar && !item.hecho }
    /// Extras, abonos, ajustes y préstamos: un solo valor, no hay "esperado".
    private var unSoloValor: Bool { item.seBorraEnVezDeDeshacer }
    private var esSalidaPrestamo: Bool { item.esSalidaDePrestamo }
    private var esSaldoInicial: Bool { item.id == Semilla.saldoInicialId }
    /// Solo los movimientos sueltos pueden pasar de pago a ingreso (los demás tienen enlaces).
    private var cambiaTipo: Bool {
        !(item.porCobrar || item.cobroId != nil || item.abono || item.deudaId != nil || esSalidaPrestamo || item.extra)
    }
    private var originalCobro: Decimal { max(item.montoOriginal ?? item.monto, item.monto) }
    private var abonado: Decimal { max(0, originalCobro - item.monto) }

    private var listo: Bool { Fmt.leerPlata(valor) != nil && !nombre.limpio.isEmpty }

    private var titulo: String {
        if esSaldoInicial { return "Saldo inicial" }
        if item.ajuste { return "Ajuste" }
        if esCobro { return "Me debe" }
        if item.cobroId != nil || item.abono { return "Abono" }
        if esSalidaPrestamo { return "Préstamo" }
        if item.extra { return "Ingreso extra" }
        return tipo == .pago ? "Editar pago" : "Editar ingreso"
    }

    private var pregunta: String {
        if esCobro { return "¿Cuánto le prestaste?" }
        if item.ajuste { return "Valor del ajuste" }
        if item.hecho { return tipo == .pago ? "¿Cuánto pagaste?" : "¿Cuánto te llegó?" }
        return tipo == .pago ? "¿Cuánto vas a pagar?" : "¿Cuánto te va a llegar?"
    }

    var body: some View {
        MarcoEdicion(titulo: titulo, puedeGuardar: listo, guardar: guardar) {
            SeccionCifra(pregunta: pregunta, texto: $valor, pie: pieCifra)

            if cambiaTipo {
                Section {
                    Picker("Tipo", selection: $tipo) {
                        if item.ajuste {
                            Text("Suma a tu plata").tag(TipoAgenda.ingreso)
                            Text("Resta de tu plata").tag(TipoAgenda.pago)
                        } else {
                            Text("Pago").tag(TipoAgenda.pago)
                            Text("Ingreso").tag(TipoAgenda.ingreso)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Tipo")
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                TextField(marcadorNombre, text: $nombre)
                    .textInputAutocapitalization(esCobro || esSalidaPrestamo ? .words : .sentences)
                    .accessibilityLabel(encabezadoNombre)
                if item.extra {
                    TextField("De dónde (clase, venta…)", text: $fuente)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityLabel("De dónde salió")
                }
            } header: {
                Text(encabezadoNombre)
            }
            .listRowBackground(Theme.superficie)

            seccionFecha

            if item.hecho && !unSoloValor && !item.porCobrar {
                Section {
                    FilaPlataEditable(titulo: "Valor esperado", texto: $esperado)
                } footer: {
                    Text("Lo que tenías previsto. La diferencia con lo real es lo que te ahorraste o te pasaste.")
                }
            }

            if esCobro && abonado > 0 {
                Section {
                    FilaDato(titulo: "Ya te pagó", valor: Fmt.plata(abonado))
                    FilaDato(titulo: "Te debe", valor: Fmt.plata(max(0, (Fmt.leerPlata(valor) ?? originalCobro) - abonado)))
                }
            }

            Section {
                TextField("Opcional", text: $nota, axis: .vertical)
                    .lineLimit(1...4)
                    .accessibilityLabel("Nota")
            } header: {
                Text("Nota")
            }
            .listRowBackground(Theme.superficie)

            if item.hecho && !unSoloValor {
                Section {
                    Button {
                        marcarPendiente()
                    } label: {
                        Label(item.tipo == .ingreso ? "Todavía no me llegó" : "Todavía no lo pagué",
                              systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(Theme.superficie)
                } footer: {
                    Text(item.porCobrar ? "Vuelve a «Me deben»." : "Vuelve a quedar pendiente en Pagos.")
                }
            }

            SeccionBorrar(
                titulo: "Borrar",
                pregunta: "¿Borrar \(item.nombre)?",
                mensaje: mensajeBorrado,
                accion: borrar
            )
        }
        .onAppear(perform: cargar)
    }

    private var pieCifra: String? {
        if esSaldoInicial { return "Lo que tenías en el banco cuando empezaste a registrar." }
        if item.abono, let deudaId = item.deudaId, let deuda = store.deuda(deudaId) {
            return "Si lo cambias, el saldo de \(deuda.nombre) se ajusta."
        }
        if let cobroId = item.cobroId, let cobro = store.data.agenda.first(where: { $0.id == cobroId }) {
            return "Si lo cambias, lo que te debe \(cobro.persona ?? cobro.nombre) se ajusta."
        }
        if item.hecho, item.tipo == .pago, let deudaId = item.deudaId, let deuda = store.deuda(deudaId) {
            return "Si lo cambias, el saldo de \(deuda.nombre) se ajusta."
        }
        return nil
    }

    private var encabezadoNombre: String {
        if esCobro { return "¿Quién te debe?" }
        if esSalidaPrestamo { return "¿A quién le prestaste?" }
        return "¿Qué es?"
    }

    private var marcadorNombre: String {
        if esCobro || esSalidaPrestamo { return "Nombre" }
        return tipo == .pago ? "Arriendo, matrícula…" : "Sueldo, venta…"
    }

    @ViewBuilder
    private var seccionFecha: some View {
        if item.hecho {
            Section {
                DatePicker(tipo == .ingreso ? "Llegó el" : "Pagado el", selection: $fecha, displayedComponents: .date)
                    .environment(\.locale, Fmt.locale)
            } header: {
                Text("Fecha")
            }
            .listRowBackground(Theme.superficie)
        } else {
            Section {
                Toggle("Tiene fecha", isOn: $conFecha.animation(.spring(response: 0.35, dampingFraction: 0.85)))
                    .tint(Theme.acento)
                if conFecha {
                    DatePicker(esCobro ? "Te paga el" : "Fecha", selection: $fecha, displayedComponents: .date)
                        .environment(\.locale, Fmt.locale)
                }
                TextField("Fecha aproximada (ej.: 16–20 nov)", text: $fechaTexto)
                    .accessibilityLabel("Fecha aproximada")
            } header: {
                Text("¿Cuándo?")
            } footer: {
                Text("La fecha aproximada es solo el texto que se muestra; la fecha de arriba es la que cuenta para los avisos.")
            }
            .listRowBackground(Theme.superficie)
        }
    }

    private var mensajeBorrado: String {
        if item.abono, let deudaId = item.deudaId, let deuda = store.deuda(deudaId) {
            return "Lo que debes en \(deuda.nombre) vuelve a subir \(Fmt.plata(item.valorEfectivo))."
        }
        if let cobroId = item.cobroId, let cobro = store.data.agenda.first(where: { $0.id == cobroId }) {
            return "Vuelve a lo que te debe \(cobro.persona ?? cobro.nombre)."
        }
        if item.porCobrar && !item.hecho {
            return "Sale de «Me deben». La salida del préstamo sigue en tus movimientos."
        }
        if item.hecho {
            return (item.tipo == .ingreso ? "Tu plata baja " : "Tu plata sube ") + "\(Fmt.plata(item.valorEfectivo))."
        }
        return "Sale de tus pagos pendientes."
    }

    // MARK: Acciones

    private func cargar() {
        guard !cargado else { return }
        cargado = true
        tipo = item.tipo
        if esCobro {
            valor = Fmt.numero(originalCobro)
            nombre = item.persona ?? item.nombre
        } else {
            valor = Fmt.numero(item.hecho ? (item.hechoMonto ?? item.monto) : item.monto)
            if esSalidaPrestamo {
                nombre = String(item.nombre.dropFirst(Self.prefijoPrestamo.count))
            } else {
                nombre = item.nombre
            }
        }
        esperado = Fmt.numero(item.monto)
        fuente = item.fuente ?? ""
        nota = item.nota ?? ""
        fechaTexto = item.fechaTexto ?? ""
        if item.hecho {
            fecha = item.hechoFecha ?? item.fecha ?? item.creado
        } else {
            conFecha = item.fecha != nil
            fecha = item.fecha ?? Date()
        }
    }

    private var actual: AgendaItem {
        store.data.agenda.first(where: { $0.id == item.id }) ?? item
    }

    private func guardar() {
        guard let v = Fmt.leerPlata(valor) else { return }
        let anterior = actual
        var copia = anterior
        let n = nombre.limpio

        if esCobro {
            copia.persona = n
            copia.nombre = n
        } else if esSalidaPrestamo {
            copia.nombre = Self.prefijoPrestamo + n
        } else {
            copia.nombre = n
        }
        if cambiaTipo { copia.tipo = tipo }
        if item.extra { copia.fuente = fuente }
        copia.nota = nota

        if esCobro {
            copia.montoOriginal = v
            copia.monto = max(0, v - abonado)
            copia.fecha = conFecha ? fecha : nil
            copia.fechaTexto = fechaTexto
        } else if copia.hecho {
            copia.hechoMonto = v
            copia.hechoFecha = fecha
            if unSoloValor {
                copia.monto = v
                copia.fecha = fecha
            } else if let e = Fmt.leerPlata(esperado) {
                copia.monto = e
            }
        } else {
            copia.monto = v
            copia.fecha = conFecha ? fecha : nil
            copia.fechaTexto = fechaTexto
        }

        store.actualizarAgenda(copia)
        let tienda = store
        ofrecerDeshacer { tienda.actualizarAgenda(anterior, aviso: nil) }
    }

    private func marcarPendiente() {
        let elemento = actual
        let monto = elemento.hechoMonto ?? elemento.monto
        let fechaHecho = elemento.hechoFecha ?? Date()
        let tienda = store
        tienda.deshacerAgenda(elemento)
        ofrecerDeshacer {
            if let ahora = tienda.data.agenda.first(where: { $0.id == elemento.id }), !ahora.hecho {
                tienda.marcarHecho(ahora, monto: monto, fecha: fechaHecho)
            }
        }
        cerrar()
    }

    private func borrar() {
        let elemento = actual
        let tienda = store
        ofrecerDeshacer(deshacer: tienda.borrarAgenda(elemento))
        cerrar()
    }
}

// MARK: - Pago de un gasto fijo

/// Corrige el valor y la fecha de un "Ya pagué" de un gasto fijo, o lo borra (vuelve a pendiente).
struct HojaEditarPagoFijo: View {
    let pago: PagoFijo

    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var cerrar
    @Environment(\.ofrecerDeshacer) private var ofrecerDeshacer

    @State private var cargado = false
    @State private var valor = ""
    @State private var fecha = Date()

    private var nombre: String { store.fijo(pago.fijoId)?.nombre ?? "Gasto fijo" }

    var body: some View {
        MarcoEdicion(titulo: nombre, puedeGuardar: Fmt.leerPlata(valor) != nil, guardar: guardar) {
            SeccionCifra(pregunta: "¿Cuánto pagaste?", texto: $valor, pie: pieDeuda)

            Section {
                DatePicker("Pagado el", selection: $fecha, displayedComponents: .date)
                    .environment(\.locale, Fmt.locale)
                    .listRowBackground(Theme.superficie)
                FilaDato(titulo: "Presupuestado", valor: Fmt.plata(pago.presupuesto))
                if let mes = Date.desdePeriodo(pago.periodo) {
                    FilaDato(titulo: "Corresponde a", valor: Fmt.mes(mes))
                }
            }

            SeccionBorrar(
                titulo: "Borrar pago",
                pregunta: "¿Borrar el pago de \(nombre)?",
                mensaje: "\(nombre) vuelve a quedar pendiente en Pagos.",
                accion: borrar
            )
        }
        .onAppear {
            guard !cargado else { return }
            cargado = true
            valor = Fmt.numero(pago.monto)
            fecha = pago.fecha
        }
    }

    private var pieDeuda: String? {
        guard let deudaId = store.fijo(pago.fijoId)?.deudaId, let deuda = store.deuda(deudaId) else { return nil }
        return "Si lo cambias, el saldo de \(deuda.nombre) se ajusta."
    }

    private var actual: PagoFijo {
        store.data.pagosFijos.first(where: { $0.id == pago.id }) ?? pago
    }

    private func guardar() {
        guard let monto = Fmt.leerPlata(valor) else { return }
        let anterior = actual
        let tienda = store
        tienda.actualizarPagoFijo(anterior, monto: monto, fecha: fecha)
        ofrecerDeshacer {
            tienda.actualizarPagoFijo(anterior, monto: anterior.monto, fecha: anterior.fecha, aviso: nil)
        }
    }

    private func borrar() {
        let anterior = actual
        let tienda = store
        tienda.deshacerPagoFijo(anterior)
        ofrecerDeshacer { tienda.restaurarPagoFijo(anterior) }
        cerrar()
    }
}

// MARK: - Gasto fijo o suscripción (en hoja)

/// La ficha de un gasto fijo dentro de una hoja (desde Pagos, Inicio o Presupuesto).
struct HojaEditarFijo: View {
    let fijoID: String
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            EditarFijoView(fijoID: fijoID)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Listo") { cerrar() }
                            .fontWeight(.semibold)
                    }
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Categoría

/// Nombre, tope, ícono y color de una categoría (también las que trae la app). Borrar la oculta.
struct HojaEditarCategoria: View {
    let categoria: Categoria

    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var cerrar
    @Environment(\.ofrecerDeshacer) private var ofrecerDeshacer

    @State private var cargado = false
    @State private var nombre = ""
    @State private var tope = ""
    @State private var simbolo = ""
    @State private var colorHex = ""

    private static let simbolos = [
        "fork.knife", "cart.fill", "cup.and.saucer.fill", "theatermasks.fill", "fuelpump.fill", "car.fill",
        "bus.fill", "airplane", "pawprint.fill", "house.fill", "bolt.fill", "wifi", "phone.fill",
        "cross.case.fill", "heart.fill", "book.fill", "graduationcap.fill", "briefcase.fill", "tshirt.fill",
        "gift.fill", "person.2.fill", "gamecontroller.fill", "film.fill", "music.note", "dumbbell.fill",
        "wrench.and.screwdriver.fill", "leaf.fill", "banknote.fill", "tag.fill", "ellipsis.circle.fill"
    ]

    private let columnas = [GridItem(.adaptive(minimum: 44), spacing: Espacio.xs)]

    private var cuantosGastos: Int { store.data.gastos.filter { $0.cat == categoria.id }.count }
    private var esLaUnica: Bool { store.categoriasVisibles.count <= 1 }

    var body: some View {
        MarcoEdicion(titulo: "Categoría", puedeGuardar: !nombre.limpio.isEmpty, guardar: guardar) {
            Section {
                HStack {
                    Spacer()
                    IconoCuadro(simbolo: simbolo.isEmpty ? categoria.simbolo : simbolo,
                                color: Color(hex: colorHex.isEmpty ? categoria.colorHex : colorHex), lado: 56)
                    Spacer()
                }
                .padding(.vertical, Espacio.xs)
            }
            .listRowBackground(Color.clear)

            Section {
                TextField("Nombre", text: $nombre)
                    .textInputAutocapitalization(.sentences)
                    .accessibilityLabel("Nombre de la categoría")
                    .listRowBackground(Theme.superficie)
            } header: {
                Text("Nombre")
            }

            Section {
                FilaPlataEditable(titulo: "Tope mensual", texto: $tope)
            } footer: {
                Text("Déjalo vacío si no le quieres poner tope.")
            }

            Section {
                LazyVGrid(columns: columnas, spacing: Espacio.xs) {
                    ForEach(opcionesSimbolo, id: \.self) { opcion in
                        let elegido = opcion == simbolo
                        Button {
                            Haptics.seleccion()
                            simbolo = opcion
                        } label: {
                            Image(systemName: opcion)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(elegido ? Theme.sobreAcento : Theme.texto)
                                .frame(width: 40, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(elegido ? Theme.acento : Theme.hundido)
                                )
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(opcion)
                        .accessibilityAddTraits(elegido ? [.isSelected] : [])
                    }
                }
                .padding(.vertical, Espacio.xxs)
                .listRowBackground(Theme.superficie)
            } header: {
                Text("Ícono")
            }

            Section {
                SelectorColor(hex: $colorHex, opciones: SelectorColor.paleta(incluyendo: categoria.colorHex))
            } header: {
                Text("Color")
            }

            SeccionBorrar(
                titulo: "Borrar categoría",
                pregunta: "¿Borrar \(categoria.nombre)?",
                mensaje: cuantosGastos > 0
                    ? "Sus \(cuantosGastos) gastos se conservan y siguen contando. Puedes volver a mostrarla en Ajustar presupuesto."
                    : "Deja de aparecer al registrar. Puedes volver a mostrarla en Ajustar presupuesto.",
                deshabilitado: esLaUnica,
                pie: esLaUnica ? "Necesitas al menos una categoría para registrar gastos." : nil,
                accion: borrar
            )
        }
        .onAppear {
            guard !cargado else { return }
            cargado = true
            nombre = categoria.nombre
            tope = categoria.mensual > 0 ? Fmt.numero(categoria.mensual) : ""
            simbolo = categoria.simbolo
            colorHex = categoria.colorHex
        }
    }

    private var opcionesSimbolo: [String] {
        Self.simbolos.contains(categoria.simbolo) ? Self.simbolos : [categoria.simbolo] + Self.simbolos
    }

    private var actual: Categoria {
        store.data.categorias.first(where: { $0.id == categoria.id }) ?? categoria
    }

    private func guardar() {
        let anterior = actual
        var copia = anterior
        copia.nombre = nombre.limpio
        copia.mensual = (Fmt.leerPlata(tope) ?? 0).redondeado
        copia.simbolo = simbolo
        copia.colorHex = colorHex
        let tienda = store
        tienda.actualizarCategoria(copia)
        tienda.avisar("Categoría actualizada")
        ofrecerDeshacer { tienda.actualizarCategoria(anterior) }
    }

    private func borrar() {
        let anterior = actual
        let tienda = store
        tienda.ocultarCategoria(anterior)
        ofrecerDeshacer { tienda.mostrarCategoria(anterior) }
        cerrar()
    }
}

// MARK: - Cajita

/// Nombre, meta, lo guardado, para qué es, color y nota de una cajita.
struct HojaEditarCajita: View {
    let cajita: Cajita

    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var cerrar
    @Environment(\.ofrecerDeshacer) private var ofrecerDeshacer

    @State private var cargado = false
    @State private var nombre = ""
    @State private var meta = ""
    @State private var guardado = ""
    @State private var nota = ""
    @State private var colorHex = ""
    @State private var para: String?

    private struct Destino: Identifiable {
        let id: String
        let nombre: String
    }

    /// Fijos y pagos pendientes que la cajita puede cubrir.
    private var destinos: [Destino] {
        var lista = store.data.fijos.map { Destino(id: $0.id, nombre: $0.nombre) }
        lista += store.data.agenda
            .filter { $0.tipo == .pago && !$0.hecho }
            .map { Destino(id: $0.id.uuidString, nombre: $0.nombre) }
        if let para = cajita.para, !lista.contains(where: { $0.id == para }) {
            let nombre = store.data.agenda.first(where: { $0.id.uuidString == para })?.nombre ?? "Lo de antes"
            lista.append(Destino(id: para, nombre: nombre))
        }
        return lista
    }

    var body: some View {
        MarcoEdicion(titulo: "Cajita", puedeGuardar: !nombre.limpio.isEmpty, guardar: guardar) {
            SeccionCifra(pregunta: "Lo que tienes guardado", texto: $guardado,
                         pie: "Cambiarlo aquí corrige lo que hay en la cajita; tu plata libre se ajusta.")

            Section {
                TextField("Viaje, matrícula, emergencias…", text: $nombre)
                    .textInputAutocapitalization(.sentences)
                    .accessibilityLabel("Nombre de la cajita")
                    .listRowBackground(Theme.superficie)
            } header: {
                Text("¿Para qué es?")
            }

            Section {
                FilaPlataEditable(titulo: "Meta", texto: $meta, marcador: "Sin meta")
                Picker("Cubre el pago de", selection: $para) {
                    Text("Nada en especial").tag(String?.none)
                    ForEach(destinos) { destino in
                        Text(destino.nombre).tag(String?.some(destino.id))
                    }
                }
                .listRowBackground(Theme.superficie)
            } footer: {
                Text("Si cubre un pago, lo guardado se descuenta de ese pago en «Hoy puedes gastar».")
            }

            Section {
                SelectorColor(hex: $colorHex, opciones: SelectorColor.paleta(incluyendo: cajita.colorHex))
            } header: {
                Text("Color")
            }

            Section {
                TextField("Opcional", text: $nota, axis: .vertical)
                    .lineLimit(1...4)
                    .accessibilityLabel("Nota")
                    .listRowBackground(Theme.superficie)
            } header: {
                Text("Nota")
            }

            SeccionBorrar(
                titulo: "Borrar cajita",
                pregunta: "¿Borrar la cajita \(cajita.nombre)?",
                mensaje: "Los \(Fmt.plata(cajita.guardado)) vuelven a tu plata libre.",
                accion: borrar
            )
        }
        .onAppear {
            guard !cargado else { return }
            cargado = true
            nombre = cajita.nombre
            meta = cajita.meta > 0 ? Fmt.numero(cajita.meta) : ""
            guardado = Fmt.numero(cajita.guardado)
            nota = cajita.nota
            colorHex = cajita.colorHex
            para = cajita.para
        }
    }

    private var actual: Cajita {
        store.data.cajitas.first(where: { $0.id == cajita.id }) ?? cajita
    }

    private func guardar() {
        let anterior = actual
        var copia = anterior
        copia.nombre = nombre
        copia.meta = Fmt.leerPlata(meta) ?? 0
        copia.guardado = Fmt.leerPlata(guardado) ?? 0
        copia.nota = nota
        copia.colorHex = colorHex
        copia.para = para
        let tienda = store
        tienda.actualizarCajita(copia)
        ofrecerDeshacer { tienda.actualizarCajita(anterior, aviso: nil) }
    }

    private func borrar() {
        let anterior = actual
        let tienda = store
        tienda.quitarCajita(anterior)
        ofrecerDeshacer { tienda.restaurarCajita(anterior) }
        cerrar()
    }
}

// MARK: - Deuda

/// Saldo, lo que se debía al principio, cuota, valor del bien y nota de una deuda.
struct HojaEditarDeuda: View {
    let deuda: Deuda

    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var cerrar
    @Environment(\.ofrecerDeshacer) private var ofrecerDeshacer

    @State private var cargado = false
    @State private var nombre = ""
    @State private var saldo = ""
    @State private var original = ""
    @State private var cuota = ""
    @State private var valorBien = ""
    @State private var nota = ""

    private var fijosQueLaPagan: [Fijo] { store.data.fijos.filter { $0.deudaId == deuda.id } }
    private var esLaTarjeta: Bool { deuda.id == "guamacard" }

    var body: some View {
        MarcoEdicion(titulo: "Deuda",
                     puedeGuardar: !nombre.limpio.isEmpty && Fmt.leerPlata(saldo) != nil,
                     guardar: guardar) {
            SeccionCifra(pregunta: "¿Cuánto debes hoy?", texto: $saldo,
                         pie: esLaTarjeta ? "Las compras con \(MetodoPago.credito.titulo) suben este saldo y pagarla lo baja." : nil)

            Section {
                TextField("Banco, tarjeta, persona…", text: $nombre)
                    .textInputAutocapitalization(.words)
                    .accessibilityLabel("A quién le debes")
                    .listRowBackground(Theme.superficie)
            } header: {
                Text("¿A quién le debes?")
            }

            Section {
                FilaPlataEditable(titulo: "Debías al principio", texto: $original)
                FilaPlataEditable(titulo: "Cuota", texto: $cuota, marcador: "Sin cuota")
                FilaPlataEditable(titulo: "Valor del bien", texto: $valorBien, marcador: "No aplica")
            } footer: {
                Text("«Debías al principio» sirve para ver cuánto llevas pagado. El valor del bien (carro, moto…) es solo una referencia: no suma a tu plata.")
            }

            if !fijosQueLaPagan.isEmpty {
                Section {
                    ForEach(fijosQueLaPagan) { fijo in
                        FilaDato(titulo: fijo.nombre, valor: fijo.dia.map { "Día \($0)" } ?? "Sin día")
                    }
                } header: {
                    Text("La bajan al pagarlos")
                } footer: {
                    Text("Se cambia en la ficha de cada gasto fijo.")
                }
            }

            Section {
                TextField("Opcional", text: $nota, axis: .vertical)
                    .lineLimit(1...4)
                    .accessibilityLabel("Nota")
                    .listRowBackground(Theme.superficie)
            } header: {
                Text("Nota")
            }

            SeccionBorrar(
                titulo: "Borrar deuda",
                pregunta: "¿Borrar la deuda \(deuda.nombre)?",
                mensaje: mensajeBorrado,
                accion: borrar
            )
        }
        .onAppear {
            guard !cargado else { return }
            cargado = true
            nombre = deuda.nombre
            saldo = Fmt.numero(deuda.saldo)
            original = Fmt.numero(deuda.original)
            cuota = deuda.cuota.map { Fmt.numero($0) } ?? ""
            valorBien = deuda.valorBien.map { Fmt.numero($0) } ?? ""
            nota = deuda.nota
        }
    }

    private var mensajeBorrado: String {
        var texto = "Sus abonos siguen en tus movimientos."
        if esLaTarjeta {
            texto += " Las compras con \(MetodoPago.credito.titulo) ya no se van a sumar a ninguna deuda."
        } else if !fijosQueLaPagan.isEmpty {
            texto += " Pagar \(fijosQueLaPagan.map(\.nombre).joined(separator: ", ")) ya no la baja."
        }
        return texto
    }

    private var actual: Deuda { store.deuda(deuda.id) ?? deuda }

    private func guardar() {
        guard let valor = Fmt.leerPlata(saldo) else { return }
        let anterior = actual
        var copia = anterior
        copia.nombre = nombre
        copia.saldo = valor
        copia.original = Fmt.leerPlata(original) ?? valor
        copia.cuota = Fmt.leerPlata(cuota)
        copia.valorBien = Fmt.leerPlata(valorBien)
        copia.nota = nota
        let tienda = store
        tienda.actualizarDeuda(copia)
        ofrecerDeshacer { tienda.actualizarDeuda(anterior, aviso: nil) }
    }

    private func borrar() {
        let anterior = actual
        let tienda = store
        tienda.quitarDeuda(anterior)
        ofrecerDeshacer { tienda.restaurarDeuda(anterior) }
        cerrar()
    }
}
