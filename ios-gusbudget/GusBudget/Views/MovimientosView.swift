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

/// Movimientos del mes. La lista va primero (agrupada por día, con búsqueda y filtros);
/// los análisis (dona, barras, horarios y hábitos) viven en el segmento "Resumen".
struct MovimientosView: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.ofrecerDeshacer) private var ofrecerDeshacer
    @Environment(\.abrirRegistro) private var abrirRegistro
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    enum Filtro: String, CaseIterable, Identifiable {
        case todo, gastos, entradas, pagos
        var id: String { rawValue }
        var titulo: String {
            switch self {
            case .todo: return "Todo"
            case .gastos: return "Gastos"
            case .entradas: return "Ingresos"
            case .pagos: return "Pagos"
            }
        }
    }

    enum Vista: String, CaseIterable, Identifiable {
        case lista, resumen
        var id: String { rawValue }
        var titulo: String { self == .lista ? "Lista" : "Resumen" }
        var simbolo: String { self == .lista ? "list.bullet" : "chart.pie" }
    }

    @State private var mes = Date().inicioDeMes
    @State private var vista: Vista = .lista
    @State private var filtro: Filtro = .todo
    @State private var busqueda = ""
    @State private var categoriaFiltro: String?
    @State private var gastoEditando: Gasto?
    @State private var detalleAbierto: Movimiento?
    @State private var porBorrar: Movimiento?

    private var animacion: Animation? {
        reducirMovimiento ? nil : .spring(response: 0.35, dampingFraction: 0.85)
    }

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

    private var textoBuscado: String {
        busqueda.trimmingCharacters(in: .whitespaces).sinTildes
    }

    private var filtrados: [Movimiento] {
        let texto = textoBuscado
        return movimientos.filter { movimiento in
            guard coincide(movimiento, filtro: filtro) else { return false }

            if let categoriaFiltro {
                guard case .gasto(let g) = movimiento, g.cat == categoriaFiltro else { return false }
            }

            if !texto.isEmpty {
                return textoBusqueda(de: movimiento).sinTildes.contains(texto)
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

    private var hayFiltros: Bool {
        filtro != .todo || categoriaFiltro != nil || !textoBuscado.isEmpty
    }

    private var mostrarFiltroCategoria: Bool {
        filtro == .todo || filtro == .gastos
    }

    // MARK: Cuerpo

    var body: some View {
        NavigationStack {
            contenido
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .environment(\.tarjetasSinSombra, true)
                .fondoPantalla()
                .scrollDismissesKeyboard(.immediately)
                .navigationTitle("Movimientos")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        MesNavegador(mes: $mes, compacto: true)
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        if vista == .lista && mostrarFiltroCategoria {
                            menuCategoria
                        }
                    }
                }
                .conBotonAjustes()
                .searchable(text: $busqueda, prompt: "Buscar por nombre o nota")
                .onChange(of: busqueda) { nuevo in
                    if !nuevo.trimmingCharacters(in: .whitespaces).isEmpty && vista != .lista {
                        withAnimation(animacion) { vista = .lista }
                    }
                }
                .onChange(of: filtro) { nuevo in
                    if nuevo == .entradas || nuevo == .pagos { categoriaFiltro = nil }
                }
                .sheet(item: $detalleAbierto) { movimiento in
                    hojaDetalle(movimiento)
                }
                .confirmationDialog(
                    tituloBorrado,
                    isPresented: Binding(
                        get: { porBorrar != nil },
                        set: { if !$0 { porBorrar = nil } }
                    ),
                    titleVisibility: .visible,
                    presenting: porBorrar
                ) { movimiento in
                    Button("Borrar", role: .destructive) { borrar(movimiento) }
                    Button("Cancelar", role: .cancel) {}
                } message: { movimiento in
                    Text("\(titulo(de: movimiento)) · \(Fmt.plata(movimiento.monto)). No se puede deshacer.")
                }
        }
        .sheet(item: $gastoEditando) { gasto in
            HojaGasto(gasto: gasto).environmentObject(store)
        }
    }

    private var contenido: some View {
        let grupos = porDia
        return List {
            Section {
                encabezado(grupos: grupos)
            }

            if vista == .lista {
                if grupos.isEmpty {
                    Section {
                        vacioLista
                            .panel()
                            .padding(.bottom, Espacio.s)
                            .filaLimpia()
                    }
                } else {
                    ForEach(grupos) { grupo in
                        Section {
                            ForEach(grupo.lista) { movimiento in
                                fila(movimiento)
                            }
                        } header: {
                            encabezadoDia(grupo)
                        }
                    }
                }
            } else {
                Section {
                    resumen
                }
            }
        }
    }

    // MARK: Encabezado (KPIs, selector y filtros)

    private func encabezado(grupos: [GrupoDia]) -> some View {
        VStack(alignment: .leading, spacing: Espacio.s) {
            SelectorVista(seleccion: $vista)
            if vista == .lista {
                lineaKPIs
                filtros
                if hayFiltros {
                    resultadoFiltros(cantidad: grupos.reduce(0) { $0 + $1.lista.count })
                }
            }
        }
        .padding(.top, Espacio.xxs)
        .padding(.bottom, Espacio.xs)
        .filaLimpia()
    }

    /// En la lista, el resumen del mes cabe en una línea; la tarjeta completa está en "Resumen".
    private var lineaKPIs: some View {
        let entrada = entro
        let salida = salio
        let diferencia = entrada - salida
        return HStack(spacing: Espacio.s) {
            datoCompacto("Entró", valor: entrada, signo: entrada > 0 ? .entrada : .ninguno)
            datoCompacto("Salió", valor: salida, signo: salida > 0 ? .salida : .ninguno)
            datoCompacto("Quedó", valor: diferencia, signo: diferencia > 0 ? .entrada : .automatico)
        }
        .padding(.horizontal, Espacio.xxs)
        .accessibilityElement(children: .combine)
    }

    private func datoCompacto(_ titulo: String, valor: Decimal, signo: CifraPlata.Signo) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(titulo)
                .font(.footnote)
                .foregroundStyle(Theme.gris)
            CifraPlata(valor: valor, estilo: .pequena, signo: signo, escalaMinima: 0.6)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tarjetaKPIs: some View {
        let entrada = entro
        let salida = salio
        let diferencia = entrada - salida
        let credito = conCredito

        return VStack(alignment: .leading, spacing: Espacio.s) {
            ResumenDatos(datos: [
                DatoResumen(titulo: "Entró", valor: entrada, signo: entrada > 0 ? .entrada : .ninguno),
                DatoResumen(titulo: "Salió", valor: salida, signo: salida > 0 ? .salida : .ninguno),
                DatoResumen(titulo: "Diferencia", valor: diferencia, signo: diferencia > 0 ? .entrada : .automatico)
            ])
            if credito > 0 {
                SeparadorFila(sangria: 0)
                HStack(alignment: .firstTextBaseline, spacing: Espacio.xs) {
                    Image(systemName: "creditcard")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.gris)
                        .accessibilityHidden(true)
                    Text("Con Guamacard gastaste \(Fmt.plata(credito)) este mes; eso se paga después.")
                        .font(.footnote)
                        .foregroundStyle(Theme.gris)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .panel()
    }

    private var filtros: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Espacio.xs) {
                ForEach(Filtro.allCases) { opcion in
                    Chip(titulo: opcion.titulo, seleccionado: filtro == opcion) {
                        withAnimation(animacion) { filtro = opcion }
                    }
                }
                // La categoría se elige en el botón de filtro de la barra; aquí solo se ve si está activa.
                if let id = categoriaFiltro, mostrarFiltroCategoria {
                    let categoria = store.categoria(id)
                    Button {
                        Haptics.seleccion()
                        withAnimation(animacion) { categoriaFiltro = nil }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: categoria.simbolo)
                                .imageScale(.small)
                            Text(categoria.nombre)
                                .lineLimit(1)
                            Image(systemName: "xmark")
                                .font(.caption2.weight(.bold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.sobreAcento)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(Capsule().fill(Theme.acento))
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.presionable)
                    .accessibilityLabel("Quitar filtro de \(categoria.nombre)")
                }
            }
            .padding(.horizontal, Espacio.xxs)
            .padding(.trailing, Espacio.margen)
        }
    }

    private var menuCategoria: some View {
        let elegida: Categoria? = categoriaFiltro.map { store.categoria($0) }
        let activa = elegida != nil

        return Menu {
            Picker("Categoría", selection: $categoriaFiltro) {
                Text("Todas las categorías").tag(String?.none)
                ForEach(store.categoriasVisibles) { categoria in
                    Label(categoria.nombre, systemImage: categoria.simbolo)
                        .tag(Optional(categoria.id))
                }
            }
        } label: {
            Image(systemName: activa ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.body.weight(.semibold))
        }
        .accessibilityLabel(elegida.map { "Categoría: \($0.nombre)" } ?? "Filtrar por categoría")
        .accessibilityAddTraits(activa ? .isSelected : [])
    }

    private func resultadoFiltros(cantidad: Int) -> some View {
        HStack(spacing: Espacio.xs) {
            Text(cantidad == 1 ? "1 movimiento" : "\(cantidad) movimientos")
                .font(.footnote)
                .foregroundStyle(Theme.gris)
            Spacer(minLength: Espacio.xs)
            Button("Limpiar filtros") { limpiarFiltros() }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.acento)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
        }
        .padding(.horizontal, Espacio.xxs)
    }

    private func limpiarFiltros() {
        Haptics.seleccion()
        withAnimation(animacion) {
            filtro = .todo
            categoriaFiltro = nil
            busqueda = ""
        }
    }

    // MARK: Lista por día

    private func encabezadoDia(_ grupo: GrupoDia) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Espacio.xs) {
            Sobrelinea(texto: Fmt.encabezadoDia(grupo.fecha))
            Spacer(minLength: Espacio.xs)
            CifraPlata(valor: grupo.total, estilo: .pequena, signo: signoDia(grupo.total), color: colorDia(grupo.total))
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
    }

    private func signoDia(_ total: Decimal) -> CifraPlata.Signo {
        if total > 0 { return .entrada }
        if total < 0 { return .salida }
        return .ninguno
    }

    private func colorDia(_ total: Decimal) -> Color? {
        total > 0 ? nil : Theme.gris
    }

    private func fila(_ movimiento: Movimiento) -> some View {
        Button {
            abrir(movimiento)
        } label: {
            FilaLista(
                simbolo: simbolo(de: movimiento),
                color: color(de: movimiento),
                titulo: titulo(de: movimiento),
                subtitulo: subtitulo(de: movimiento),
                insignia: insignia(de: movimiento)
            ) {
                CifraPlata(valor: movimiento.monto, estilo: .normal, signo: movimiento.esEntrada ? .entrada : .salida)
            }
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.presionable)
        .accessibilityHint(esGasto(movimiento) ? "Toca para corregirlo o borrarlo" : "Toca para ver el detalle")
        .listRowInsets(EdgeInsets())
        .listRowBackground(Theme.superficie)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            accionesDeslizar(movimiento)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if case .gasto(let gasto) = movimiento {
                Button {
                    gastoEditando = gasto
                } label: {
                    Label("Editar", systemImage: "pencil")
                }
                .tint(Theme.acento)
            }
        }
        .contextMenu {
            accionesMenu(movimiento)
        }
    }

    @ViewBuilder
    private func accionesDeslizar(_ movimiento: Movimiento) -> some View {
        if puedeBorrar(movimiento) {
            Button {
                pedirBorrado(movimiento)
            } label: {
                Label("Borrar", systemImage: "trash")
            }
            .tint(Theme.rojo)
        }
        if puedeDeshacer(movimiento) {
            Button {
                deshacer(movimiento)
            } label: {
                Label("Deshacer", systemImage: "arrow.uturn.backward")
            }
            .tint(Theme.ambarRelleno)
        }
    }

    @ViewBuilder
    private func accionesMenu(_ movimiento: Movimiento) -> some View {
        if case .gasto(let gasto) = movimiento {
            Button {
                gastoEditando = gasto
            } label: {
                Label("Editar gasto", systemImage: "pencil")
            }
        } else {
            Button {
                detalleAbierto = movimiento
            } label: {
                Label("Ver detalle", systemImage: "info.circle")
            }
        }
        if puedeDeshacer(movimiento) {
            Button {
                deshacer(movimiento)
            } label: {
                Label(tituloDeshacer(movimiento), systemImage: "arrow.uturn.backward")
            }
        }
        if puedeBorrar(movimiento) {
            Button(role: .destructive) {
                pedirBorrado(movimiento)
            } label: {
                Label("Borrar", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var vacioLista: some View {
        if !hayFiltros || movimientos.isEmpty {
            if mes.mismoMes(que: Date()) {
                EstadoVacio(
                    simbolo: "tray",
                    titulo: "Todavía no hay movimientos este mes",
                    mensaje: "Lo que gastes, te paguen o pagues aparece aquí, día por día.",
                    accionTitulo: "Registrar gasto",
                    accion: { abrirRegistro() }
                )
            } else {
                EstadoVacio(
                    simbolo: "tray",
                    titulo: "No hay movimientos en \(Fmt.mes(mes))",
                    mensaje: "Usa las flechas de arriba para ver otro mes."
                )
            }
        } else {
            EstadoVacio(
                simbolo: "line.3.horizontal.decrease.circle",
                titulo: "Nada con ese filtro",
                mensaje: textoBuscado.isEmpty
                    ? "Prueba con otro tipo o con otra categoría."
                    : "No encontré “\(busqueda.trimmingCharacters(in: .whitespaces))” en \(Fmt.mes(mes)).",
                accionTitulo: "Limpiar filtros",
                accion: { limpiarFiltros() }
            )
        }
    }

    // MARK: Resumen del mes

    private var resumen: some View {
        VStack(alignment: .leading, spacing: Espacio.seccion) {
            tarjetaKPIs
            seccionDona
            seccionBarras
            seccionHorarios
            seccionHabitos
        }
        .padding(.bottom, Espacio.m)
        .filaLimpia()
    }

    private var seccionDona: some View {
        let totales = store.totalesPorCategoria(mes: mes)
        let total = totales.reduce(Decimal.zero) { $0 + $1.total }
        let tramos: [TramoDona] = totales.prefix(6).map {
            TramoDona(id: $0.categoria.id, valor: $0.total.doble, color: $0.categoria.color, nombre: $0.categoria.nombre)
        }
        let resto = totales.dropFirst(6)
        let totalResto = resto.reduce(Decimal.zero) { $0 + $1.total }

        return VStack(alignment: .leading, spacing: Espacio.titulo) {
            EncabezadoSeccion(titulo: "En qué se fue tu plata", detalle: totales.isEmpty ? nil : "Tus gastos del mes por categoría")
            VStack(alignment: .leading, spacing: Espacio.s) {
                if totales.isEmpty {
                    Vacio(simbolo: "chart.pie", texto: "Cuando registres gastos verás aquí en qué se te va la plata.")
                } else {
                    DonaConLeyenda(tramos: tramos, total: total)
                    if !resto.isEmpty {
                        Text(resto.count == 1
                             ? "Y 1 categoría más: \(Fmt.plata(totalResto))"
                             : "Y \(resto.count) categorías más: \(Fmt.plata(totalResto))")
                            .font(.footnote)
                            .foregroundStyle(Theme.gris)
                    }
                }
            }
            .panel()
        }
    }

    private var seccionBarras: some View {
        let diario = store.presupuestoDiario(mes: mes)
        return VStack(alignment: .leading, spacing: Espacio.titulo) {
            EncabezadoSeccion(
                titulo: "Día por día",
                detalle: diario > 0
                    ? "La línea punteada es tu presupuesto diario. Toca una barra para ver ese día."
                    : "Toca una barra para ver cuánto gastaste ese día."
            )
            BarrasPorDia(dias: store.totalesPorDia(mes: mes), presupuestoDiario: diario)
                .padding(.top, Espacio.xs)
                .panel()
        }
    }

    @ViewBuilder
    private var seccionHorarios: some View {
        let resultado = store.franjas(mes: mes)
        let total = resultado.franjas.reduce(Decimal.zero) { $0 + $1.total }
        if total > 0 {
            VStack(alignment: .leading, spacing: Espacio.titulo) {
                EncabezadoSeccion(titulo: "Tus horarios", detalle: "A qué horas se te va la plata")
                VStack(alignment: .leading, spacing: Espacio.m) {
                    ForEach(resultado.franjas) { franja in
                        filaFranja(franja, total: total)
                    }
                    if resultado.sinHora > 0 {
                        Text(resultado.sinHora == 1
                             ? "1 gasto no tiene hora anotada."
                             : "\(resultado.sinHora) gastos no tienen hora anotada.")
                            .font(.footnote)
                            .foregroundStyle(Theme.gris)
                    }
                }
                .panel()
            }
        }
    }

    private func filaFranja(_ franja: Franja, total: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: Espacio.xs) {
                Text(franja.nombre)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.texto)
                Text(franja.cantidad == 1 ? "1 gasto" : "\(franja.cantidad) gastos")
                    .font(.footnote)
                    .foregroundStyle(Theme.gris)
                Spacer(minLength: Espacio.xs)
                CifraPlata(valor: franja.total, estilo: .pequena, signo: .ninguno)
            }
            BarraProgreso(
                avance: total > 0 ? franja.total.doble / total.doble : 0,
                color: Theme.acento,
                alto: 8,
                etiqueta: "Parte de tus gastos en \(franja.nombre)"
            )
            if let comun = franja.masComun {
                Text("Lo más común: \(comun)")
                    .font(.footnote)
                    .foregroundStyle(Theme.gris)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var seccionHabitos: some View {
        let habitos = Array(store.habitos().prefix(5))
        if !habitos.isEmpty {
            VStack(alignment: .leading, spacing: Espacio.titulo) {
                EncabezadoSeccion(titulo: "Lo que más repites", detalle: "Tus gastos más frecuentes")
                VStack(spacing: 0) {
                    ForEach(Array(habitos.enumerated()), id: \.element.id) { indice, habito in
                        if indice > 0 { SeparadorFila() }
                        filaHabito(habito)
                    }
                }
                .panel(padding: 0)
            }
        }
    }

    private func filaHabito(_ habito: Habito) -> some View {
        let categoria = store.categoria(habito.categoriaID)
        return FilaLista(
            simbolo: categoria.simbolo,
            color: categoria.color,
            titulo: habito.titulo,
            subtitulo: habito.descripcion
        ) {
            EmptyView()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Acciones

    private func abrir(_ movimiento: Movimiento) {
        if case .gasto(let gasto) = movimiento {
            gastoEditando = gasto
        } else {
            detalleAbierto = movimiento
        }
    }

    private func esGasto(_ movimiento: Movimiento) -> Bool {
        if case .gasto = movimiento { return true }
        return false
    }

    /// Igual que en "Ya hechos" de Pagos: los ingresos extra y los abonos se borran; lo demás se deshace.
    private func puedeBorrar(_ movimiento: Movimiento) -> Bool {
        switch movimiento {
        case .gasto: return true
        case .agenda(let a): return a.seBorraEnVezDeDeshacer
        case .fijo: return false
        }
    }

    private func puedeDeshacer(_ movimiento: Movimiento) -> Bool {
        switch movimiento {
        case .gasto: return false
        case .agenda(let a): return !a.seBorraEnVezDeDeshacer
        case .fijo: return true
        }
    }

    private func tituloDeshacer(_ movimiento: Movimiento) -> String {
        switch movimiento {
        case .agenda(let a): return "Deshacer “\(a.tipo.accion)”"
        default: return "Deshacer “Ya pagué”"
        }
    }

    private var tituloBorrado: String {
        if let porBorrar, esGasto(porBorrar) { return "¿Borrar este gasto?" }
        return "¿Borrar este movimiento?"
    }

    private func pedirBorrado(_ movimiento: Movimiento) {
        Haptics.warning()
        porBorrar = movimiento
    }

    private func borrar(_ movimiento: Movimiento) {
        switch movimiento {
        case .gasto(let gasto):
            withAnimation(animacion) { store.borrarGasto(gasto) }
        case .agenda(let item):
            withAnimation(animacion) { store.quitarAgenda(item) }
        case .fijo:
            break
        }
        porBorrar = nil
    }

    /// Revierte un "Ya pagué" / "Ya me llegó" y ofrece volver a marcarlo desde el toast.
    private func deshacer(_ movimiento: Movimiento) {
        switch movimiento {
        case .agenda(let item):
            let monto = item.hechoMonto ?? item.monto
            let fecha = item.hechoFecha ?? item.fecha ?? item.creado
            withAnimation(animacion) { store.deshacerAgenda(item) }
            ofrecerDeshacer {
                // Si ya lo volvió a marcar, no se registra (ni se descuenta la deuda) dos veces.
                if let actual = store.data.agenda.first(where: { $0.id == item.id }), !actual.hecho {
                    store.marcarHecho(actual, monto: monto, fecha: fecha)
                }
            }
        case .fijo(let pago, _):
            withAnimation(animacion) { store.deshacerPagoFijo(pago) }
            ofrecerDeshacer {
                if store.pagoDeFijo(pago.fijoId, periodo: pago.periodo) == nil,
                   let fijo = store.fijo(pago.fijoId) {
                    store.pagarFijo(fijo, periodo: pago.periodo, monto: pago.monto, fecha: pago.fecha)
                }
            }
        case .gasto:
            break
        }
    }

    // MARK: Hoja de detalle (pagos e ingresos)

    private func hojaDetalle(_ movimiento: Movimiento) -> some View {
        let borra = puedeBorrar(movimiento)
        let deshace = puedeDeshacer(movimiento)
        let tituloAccion: String? = borra ? "Borrar" : (deshace ? tituloDeshacer(movimiento) : nil)

        return HojaDetalleMovimiento(
            simbolo: simbolo(de: movimiento),
            color: color(de: movimiento),
            titulo: titulo(de: movimiento),
            tipo: tipo(de: movimiento),
            monto: movimiento.monto,
            esEntrada: movimiento.esEntrada,
            datos: datosDetalle(de: movimiento),
            tituloAccion: tituloAccion,
            destructiva: borra,
            notaAccion: deshace ? "Vuelve a quedar pendiente en Pagos." : nil,
            accion: {
                if borra {
                    borrar(movimiento)
                } else if deshace {
                    deshacer(movimiento)
                }
            }
        )
    }

    private func datosDetalle(de movimiento: Movimiento) -> [DatoDetalle] {
        var lista = [DatoDetalle(titulo: "Fecha", valor: Fmt.encabezadoDia(movimiento.fecha))]
        switch movimiento {
        case .gasto:
            break
        case .agenda(let a):
            if let fuente = a.fuente, !fuente.isEmpty, fuente != a.nombre {
                lista.append(DatoDetalle(titulo: "De dónde", valor: fuente))
            }
            if let persona = a.persona, !persona.isEmpty, persona != a.nombre {
                lista.append(DatoDetalle(titulo: "Persona", valor: persona))
            }
            if let hecho = a.hechoMonto, hecho != a.monto {
                lista.append(DatoDetalle(titulo: "Valor esperado", valor: Fmt.plata(a.monto)))
            }
            if let nota = a.nota, !nota.isEmpty, nota != a.nombre {
                lista.append(DatoDetalle(titulo: "Nota", valor: nota))
            }
        case .fijo(let p, _):
            if p.presupuesto != p.monto {
                lista.append(DatoDetalle(titulo: "Presupuestado", valor: Fmt.plata(p.presupuesto)))
            }
            if p.ahorro > 0 {
                lista.append(DatoDetalle(titulo: "Te ahorraste", valor: Fmt.plata(p.ahorro)))
            }
            if let periodo = Date.desdePeriodo(p.periodo), !periodo.mismoMes(que: p.fecha) {
                lista.append(DatoDetalle(titulo: "Corresponde a", valor: Fmt.mes(periodo)))
            }
        }
        return lista
    }

    // MARK: Textos de cada fila

    private func titulo(de movimiento: Movimiento) -> String {
        switch movimiento {
        case .gasto(let g):
            let nota = g.nota.trimmingCharacters(in: .whitespacesAndNewlines)
            return nota.isEmpty ? store.categoria(g.cat).nombre : nota.mayusculaInicial
        case .agenda(let a): return a.nombre
        case .fijo(_, let nombre): return nombre
        }
    }

    private func subtitulo(de movimiento: Movimiento) -> String? {
        switch movimiento {
        case .gasto(let g):
            var partes: [String] = []
            if !g.nota.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                partes.append(store.categoria(g.cat).nombre)
            }
            if let hora = g.hora, !hora.isEmpty { partes.append(hora) }
            return partes.isEmpty ? "Gasto" : partes.joined(separator: " · ")
        case .agenda, .fijo:
            return tipo(de: movimiento)
        }
    }

    private func tipo(de movimiento: Movimiento) -> String {
        switch movimiento {
        case .gasto: return "Gasto"
        case .agenda(let a): return a.extra ? "Ingreso extra" : a.tipo.titulo
        case .fijo: return "Pago fijo"
        }
    }

    private func insignia(de movimiento: Movimiento) -> Insignia? {
        if case .gasto(let g) = movimiento, g.metodo == .credito {
            return Insignia(texto: "Guamacard", tono: .neutro, simbolo: "creditcard")
        }
        return nil
    }

    /// Todo lo que la búsqueda puede encontrar de un movimiento.
    private func textoBusqueda(de movimiento: Movimiento) -> String {
        switch movimiento {
        case .gasto(let g):
            let metodo = g.metodo == .credito ? "Guamacard Crédito" : ""
            return [store.categoria(g.cat).nombre, g.nota, "Gasto", metodo].joined(separator: " ")
        case .agenda(let a):
            let tipo = a.tipo == .ingreso ? "Ingreso Entrada" : "Pago"
            return [a.nombre, tipo, a.fuente ?? "", a.nota ?? "", a.persona ?? ""].joined(separator: " ")
        case .fijo(_, let nombre):
            return [nombre, "Gasto fijo Pago fijo"].joined(separator: " ")
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

// MARK: - Selector Lista | Resumen

/// Control segmentado propio: pastilla clara sobre pista hundida, legible en claro y en oscuro.
private struct SelectorVista: View {
    @Binding var seleccion: MovimientosView.Vista

    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @Namespace private var espacio

    private let pildora = Theme.dynamic(light: "FFFFFF", dark: "2C3766")

    var body: some View {
        HStack(spacing: Espacio.xxs) {
            ForEach(MovimientosView.Vista.allCases) { opcion in
                boton(opcion)
            }
        }
        .padding(Espacio.xxs)
        .background(Capsule(style: .continuous).fill(Theme.hundido))
        .accessibilityElement(children: .contain)
    }

    private func boton(_ opcion: MovimientosView.Vista) -> some View {
        let activa = opcion == seleccion
        return Button {
            guard !activa else { return }
            Haptics.seleccion()
            withAnimation(reducirMovimiento ? nil : .spring(response: 0.35, dampingFraction: 0.85)) {
                seleccion = opcion
            }
        } label: {
            Label(opcion.titulo, systemImage: opcion.simbolo)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(activa ? Theme.texto : Theme.gris)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    if activa {
                        Capsule(style: .continuous)
                            .fill(pildora)
                            .shadow(color: Theme.sombra, radius: 4, x: 0, y: 1)
                            .matchedGeometryEffect(id: "pildora", in: espacio)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(opcion.titulo)
        .accessibilityAddTraits(activa ? .isSelected : [])
    }
}

// MARK: - Detalle de un pago o ingreso

private struct DatoDetalle: Identifiable {
    let titulo: String
    let valor: String
    var id: String { titulo }
}

/// Hoja con el detalle de un pago o ingreso ya hecho, con su única acción (deshacer o borrar).
private struct HojaDetalleMovimiento: View {
    let simbolo: String
    let color: Color
    let titulo: String
    let tipo: String
    let monto: Decimal
    let esEntrada: Bool
    let datos: [DatoDetalle]
    let tituloAccion: String?
    let destructiva: Bool
    let notaAccion: String?
    let accion: () -> Void

    @Environment(\.dismiss) private var cerrar
    @State private var confirmar = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Espacio.xl) {
                    cabecera
                    if !datos.isEmpty { tarjetaDatos }
                    if let tituloAccion { zonaAccion(tituloAccion) }
                }
                .padding(.horizontal, Espacio.margen)
                .padding(.top, Espacio.xs)
                .padding(.bottom, Espacio.xl)
                .frame(maxWidth: 576)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.fondo.ignoresSafeArea())
            .navigationTitle(tipo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { cerrar() }
                        .fontWeight(.semibold)
                }
            }
            .confirmationDialog("¿Borrar este movimiento?", isPresented: $confirmar, titleVisibility: .visible) {
                Button("Borrar", role: .destructive) { ejecutar() }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("\(titulo) · \(Fmt.plata(monto)). No se puede deshacer.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var cabecera: some View {
        VStack(spacing: Espacio.s) {
            IconoCuadro(simbolo: simbolo, color: color, lado: 56)
            Text(titulo)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.texto)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            CifraPlata(valor: monto, estilo: .titular, signo: esEntrada ? .entrada : .salida)
            Insignia(texto: tipo, tono: esEntrada ? .positivo : .neutro)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Espacio.s)
        .accessibilityElement(children: .combine)
    }

    private var tarjetaDatos: some View {
        VStack(spacing: 0) {
            ForEach(Array(datos.enumerated()), id: \.element.id) { indice, dato in
                if indice > 0 { SeparadorFila(sangria: Espacio.m) }
                HStack(alignment: .firstTextBaseline, spacing: Espacio.s) {
                    Text(dato.titulo)
                        .foregroundStyle(Theme.gris)
                    Spacer(minLength: Espacio.s)
                    Text(dato.valor)
                        .foregroundStyle(Theme.texto)
                        .multilineTextAlignment(.trailing)
                }
                .font(.subheadline)
                .padding(.horizontal, Espacio.m)
                .padding(.vertical, Espacio.s)
                .frame(minHeight: 48)
                .accessibilityElement(children: .combine)
            }
        }
        .panel(padding: 0)
    }

    private func zonaAccion(_ titulo: String) -> some View {
        VStack(spacing: Espacio.xs) {
            Button {
                if destructiva {
                    Haptics.warning()
                    confirmar = true
                } else {
                    ejecutar()
                }
            } label: {
                Label(titulo, systemImage: destructiva ? "trash" : "arrow.uturn.backward")
            }
            .buttonStyle(.secundario(destructiva ? Theme.rojo : Theme.acento, anchoCompleto: true))

            if let notaAccion {
                Text(notaAccion)
                    .font(.footnote)
                    .foregroundStyle(Theme.gris)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func ejecutar() {
        accion()
        cerrar()
    }
}

// MARK: - Utilidades

private extension View {
    /// Fila de List sin fondo, sin márgenes y sin separador (para tarjetas propias dentro de la lista).
    func filaLimpia() -> some View {
        self
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
