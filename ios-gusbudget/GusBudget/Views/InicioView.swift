import SwiftUI

/// Pantalla de inicio: la cifra de "Hoy puedes gastar" es la protagonista.
/// Debajo, un solo aviso, lo que viene en los próximos 7 días y en qué se va la plata del mes.
/// El registro ya no va aquí: se abre desde el botón "+" (o desde el estado vacío).
struct InicioView: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.ofrecerDeshacer) private var ofrecerDeshacer
    @Environment(\.irAPestana) private var irAPestana
    @Environment(\.abrirRegistro) private var abrirRegistro
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    @State private var solicitud: SolicitudValor?
    @State private var mostrarExplicacion = false
    @State private var verTodosLosAvisos = false

    /// Máximo de filas de "Próximos 7 días" en Inicio; el resto está en Pagos.
    private let maxProximos = 4

    private var resultado: ResultadoHoy { store.hoyPuedesGastar() }
    private var pendientes: [Obligacion] { store.obligaciones() }

    /// Pagos e ingresos vencidos o de los próximos 7 días (ya vienen ordenados por estado y fecha).
    private var cerca: [Obligacion] {
        pendientes.filter { ($0.tipo == .pago || $0.tipo == .ingreso) && ($0.estado == .vencido || $0.estado == .pronto) }
    }

    private var animacion: Animation? {
        reducirMovimiento ? nil : .spring(response: 0.35, dampingFraction: 0.85)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Espacio.seccion) {
                    VStack(alignment: .leading, spacing: Espacio.s) {
                        tarjetaHoy
                        avisos
                    }
                    proximos
                    donaDelMes
                }
                .contenidoPantalla()
            }
            .scrollDismissesKeyboard(.interactively)
            .fondoPantalla()
            .navigationTitle(saludo)
            .navigationBarTitleDisplayMode(.large)
            .conBotonAjustes()
            .sheet(item: $solicitud) { peticion in
                HojaValorReal(solicitud: peticion)
            }
            .sheet(isPresented: $mostrarExplicacion) {
                HojaComoSeCalcula(resultado: resultado, explicacion: frase)
            }
        }
    }

    private var saludo: String {
        let hora = Calendar.app.component(.hour, from: Date())
        switch hora {
        case 5..<12: return "Buenos días"
        case 12..<19: return "Buenas tardes"
        default: return "Buenas noches"
        }
    }

    // MARK: Tarjeta principal

    private var tarjetaHoy: some View {
        let r = resultado
        let pasado = r.disponible < 0
        let enCero = !pasado && r.disponible <= 0

        return TarjetaHero(espaciado: Espacio.s) {
            HStack(alignment: .center, spacing: Espacio.xs) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Fmt.fechaCorta(Date()))
                        .font(.sobrelinea)
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(Theme.gris)
                    Text(pasado ? "Hoy te pasaste" : "Hoy puedes gastar")
                        .font(.headline)
                        .foregroundStyle(Theme.texto)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: Espacio.xs)
                BotonIcono(simbolo: "info", etiqueta: "¿Cómo se calcula?", color: Theme.texto) {
                    mostrarExplicacion = true
                }
                .padding(.trailing, -Espacio.xs)
            }

            CifraPlata(valor: abs(r.disponible), estilo: .hero, signo: .ninguno,
                       color: pasado ? .white : (enCero ? Color.white.opacity(0.7) : Theme.sol))
                .accessibilityLabel(pasado
                                    ? "Te pasaste \(CifraPlata.textoAccesible(abs(r.disponible), signo: .ninguno))"
                                    : "Hoy puedes gastar \(CifraPlata.textoAccesible(r.disponible, signo: .ninguno))")
                .padding(.top, -Espacio.xxs)

            HStack(spacing: Espacio.xs) {
                if pasado {
                    Insignia(texto: "Por encima del límite", tono: .negativo, simbolo: "arrow.up")
                }
                Text(contexto)
                    .font(.subheadline)
                    .foregroundStyle(Theme.gris)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if r.permitido > 0 || r.gastadoHoy > 0 {
                barraDeHoy(r)
                    .padding(.top, Espacio.xxs)
            }

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 0.5)
                .padding(.vertical, Espacio.xxs)
                .accessibilityHidden(true)

            ResumenDatos(datos: [
                DatoResumen(titulo: "Plata libre", valor: store.libre),
                DatoResumen(titulo: "Ahorrado", valor: store.enCajitas),
                DatoResumen(titulo: "Esta semana", valor: store.gastadoEstaSemana)
            ], sobreOscuro: true)
        }
    }

    private func barraDeHoy(_ r: ResultadoHoy) -> some View {
        let avance = r.permitido > 0 ? r.gastadoHoy.doble / r.permitido.doble : 1
        return VStack(alignment: .leading, spacing: 6) {
            BarraProgreso(avance: avance,
                          color: avance > 1 ? Theme.rojo : Theme.sol,
                          alto: 6,
                          etiqueta: "Gastado hoy")
            HStack(spacing: Espacio.xs) {
                Text("Gastado hoy")
                Spacer(minLength: Espacio.xs)
                Text("\(Fmt.plata(r.gastadoHoy)) de \(Fmt.plata(r.permitido))")
                    .monospacedDigit()
            }
            .font(.footnote)
            .foregroundStyle(Theme.gris)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Gastado hoy: \(CifraPlata.textoAccesible(r.gastadoHoy, signo: .ninguno)) de \(CifraPlata.textoAccesible(r.permitido, signo: .ninguno))")
        }
    }

    /// Una sola línea de contexto debajo de la cifra.
    private var contexto: String {
        let r = resultado
        if r.disponible < 0 { return "Mañana vuelve a empezar" }
        if r.disponible <= 0 {
            if r.permitido > 0 { return "Ya usaste lo de hoy. Mañana vuelves a tener plata." }
            if r.libre <= 0 { return "Tu plata libre está en $ 0. Registra un ingreso para calcular." }
            return "Tu plata libre ya está apartada para los pagos que vienen."
        }
        let dias = r.dias == 1 ? "1 día" : "\(r.dias) días"
        if r.mandaPresupuesto { return "Según tu presupuesto del mes" }
        if let ingreso = r.proximoIngreso { return "Hasta que llegue \(ingreso.nombre) · \(dias)" }
        return "Hasta fin de mes · \(dias)"
    }

    /// La explicación completa (va en la hoja "¿Cómo se calcula?").
    private var frase: String {
        let r = resultado
        if r.disponible < 0 {
            return "Te pasaste del límite de hoy. Mañana vuelve a empezar."
        }
        if r.mandaPresupuesto {
            return "Manda tu presupuesto del mes: es lo que queda del día a día repartido en los días que faltan."
        }
        let destino = r.proximoIngreso.map { "hasta que llegue \($0.nombre)" } ?? "hasta que acabe el mes"
        let dias = r.dias == 1 ? "1 día" : "\(r.dias) días"
        return "Tienes \(Fmt.plata(r.libre)) libres, apartas \(Fmt.plata(r.pagosAntes)) para pagos y lo repartes en \(dias), \(destino)."
    }

    // MARK: Avisos

    @ViewBuilder
    private var avisos: some View {
        let lista = store.avisos()
        let caducidad = avisoCaducidad

        if caducidad != nil || !lista.isEmpty {
            VStack(spacing: Espacio.xs) {
                if let caducidad {
                    BannerAviso(simbolo: "clock.fill", titulo: caducidad,
                                mensaje: "Tus datos se quedan en el teléfono.", tono: .negativo)
                }

                if let primero = lista.first {
                    let resto = Array(lista.dropFirst())
                    // El primer aviso siempre lleva a donde se arregla; el desplegable va aparte.
                    BannerAviso(titulo: primero, tono: tono(de: primero), accion: accionDe(primero))

                    if !resto.isEmpty {
                        if verTodosLosAvisos {
                            ForEach(Array(resto.enumerated()), id: \.offset) { _, texto in
                                BannerAviso(titulo: texto, tono: tono(de: texto), accion: accionDe(texto))
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        Button {
                            withAnimation(animacion) { verTodosLosAvisos.toggle() }
                        } label: {
                            HStack(spacing: 4) {
                                Text(verTodosLosAvisos
                                     ? "Ocultar avisos"
                                     : (resto.count == 1 ? "+1 aviso más" : "+\(resto.count) avisos más"))
                                Image(systemName: verTodosLosAvisos ? "chevron.up" : "chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .accessibilityHidden(true)
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.acento)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.presionable)
                        .accessibilityHint(verTodosLosAvisos ? "Oculta los demás avisos" : "Muestra los demás avisos")
                    }
                }
            }
        }
    }

    private var avisoCaducidad: String? {
        guard let dias = RenewalReminder.daysRemaining(signedOn: store.data.ajustes.ultimaFirma),
              dias <= 1 else { return nil }
        return dias <= 0 ? "La app caduca hoy: reinstálala" : "La app caduca mañana: reinstálala"
    }

    private func tono(de texto: String) -> Tono {
        let minusculas = texto.lowercased()
        if store.libre < 0 && minusculas.contains("plata libre") { return .negativo }
        if minusculas.contains("no te alcanza") { return .negativo }
        return .aviso
    }

    /// Lleva a la pestaña donde se arregla el aviso.
    private func accionDe(_ texto: String) -> (() -> Void)? {
        let minusculas = texto.lowercased()
        let ir = irAPestana
        if minusculas.contains("presupuesto") {
            return { ir(.presupuesto) }
        }
        if minusculas.contains("pagos") {
            return { ir(.pagos) }
        }
        return nil
    }

    // MARK: Próximos 7 días

    private var proximos: some View {
        let lista = cerca
        // Lo que te deben no está en Pagos (vive en Balance): nunca se esconde aquí.
        let visibles = lista.enumerated()
            .filter { $0.offset < maxProximos || $0.element.porCobrar }
            .map(\.element)
        let ocultos = lista.count - visibles.count

        return VStack(alignment: .leading, spacing: Espacio.titulo) {
            EncabezadoSeccion(titulo: "Próximos 7 días", detalle: resumenProximos(lista),
                              accionTitulo: "Ver todos") {
                irAPestana(.pagos)
            }

            VStack(spacing: 0) {
                if visibles.isEmpty {
                    sinProximos
                } else {
                    ForEach(Array(visibles.enumerated()), id: \.element.id) { indice, obligacion in
                        if indice > 0 { SeparadorFila(sangria: 56) }
                        FilaObligacion(obligacion: obligacion, alHacer: {
                            pedirValor(obligacion)
                        })
                        .padding(.horizontal, Espacio.m)
                        .padding(.vertical, Espacio.xxs)
                    }
                    if ocultos > 0 {
                        SeparadorFila(sangria: 0)
                        Button {
                            irAPestana(.pagos)
                        } label: {
                            HStack {
                                Text(ocultos == 1 ? "1 más esta semana" : "\(ocultos) más esta semana")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .accessibilityHidden(true)
                            }
                            .foregroundStyle(Theme.acento)
                            .padding(.horizontal, Espacio.m)
                            .frame(minHeight: 48)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.presionable)
                    }
                }
            }
            .panel(padding: 0)
        }
    }

    private func resumenProximos(_ lista: [Obligacion]) -> String? {
        let pagos = lista.filter { $0.tipo == .pago }.reduce(Decimal.zero) { $0 + $1.monto }
        let ingresos = lista.filter { $0.tipo == .ingreso }.reduce(Decimal.zero) { $0 + $1.monto }
        var partes: [String] = []
        if pagos > 0 { partes.append("Pagas \(Fmt.plata(pagos))") }
        if ingresos > 0 { partes.append("Te llegan \(Fmt.plata(ingresos))") }
        return partes.isEmpty ? nil : partes.joined(separator: " · ")
    }

    private var sinProximos: some View {
        let siguiente = pendientes.first
        return HStack(spacing: Espacio.s) {
            IconoCuadro(simbolo: "checkmark", color: Theme.verde, lado: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Nada por pagar esta semana")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.texto)
                Text(siguiente.map { "Lo siguiente: \($0.nombre), \($0.fechaMostrada)" }
                     ?? "No tienes pendientes. Qué maravilla.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.gris)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Espacio.m)
        .padding(.vertical, Espacio.s)
        .frame(minHeight: 60)
        .accessibilityElement(children: .combine)
    }

    /// Abre "¿Cuánto pagaste de verdad?" y, al guardar, ofrece deshacer.
    private func pedirValor(_ obligacion: Obligacion) {
        let base = solicitudPara(obligacion, store: store)
        var conDeshacer = base
        let tienda = store
        let ofrecer = ofrecerDeshacer
        conDeshacer.accion = { monto, fecha in
            base.accion(monto, fecha)
            guard !obligacion.porCobrar else { return }
            ofrecer(nil) { InicioView.revertir(obligacion, store: tienda) }
        }
        solicitud = conDeshacer
    }

    /// Deja otra vez pendiente una obligación recién marcada como hecha.
    private static func revertir(_ obligacion: Obligacion, store: FinanceStore) {
        if let fijoId = obligacion.fijoId, let periodo = obligacion.periodo {
            if let pago = store.pagoDeFijo(fijoId, periodo: periodo) {
                store.deshacerPagoFijo(pago)
            }
            return
        }
        if let agendaId = obligacion.agendaId,
           let item = store.data.agenda.first(where: { $0.id == agendaId }),
           item.hecho {
            store.deshacerAgenda(item)
        }
    }

    // MARK: Dona del mes

    @ViewBuilder
    private var donaDelMes: some View {
        let totales = store.totalesPorCategoria(mes: Date())

        VStack(alignment: .leading, spacing: Espacio.titulo) {
            if totales.isEmpty {
                EncabezadoSeccion(titulo: "En qué se va tu plata", detalle: Fmt.mes(Date()))
                EstadoVacio(
                    simbolo: "chart.pie.fill",
                    titulo: "Registra tu primer gasto",
                    mensaje: "Así ves en qué se te va la plata y cuánto puedes gastar cada día.",
                    accionTitulo: "Registrar gasto"
                ) {
                    abrirRegistro()
                }
                .panel(padding: 0)
            } else {
                let total = totales.reduce(Decimal.zero) { $0 + $1.total }
                EncabezadoSeccion(titulo: "En qué se va tu plata", detalle: Fmt.mes(Date()),
                                  accionTitulo: "Ver más") {
                    irAPestana(.movimientos)
                }
                DonaConLeyenda(tramos: tramosDona(totales), total: total)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .panel()
            }
        }
    }

    /// Las 4 categorías principales y el resto agrupado en "Otras".
    private func tramosDona(_ totales: [TotalCategoria]) -> [TramoDona] {
        var lista = totales.prefix(4).map {
            TramoDona(id: $0.categoria.id, valor: $0.total.doble, color: $0.categoria.color, nombre: $0.categoria.nombre)
        }
        let otras = totales.dropFirst(4).reduce(Decimal.zero) { $0 + $1.total }
        if otras > 0 {
            lista.append(TramoDona(id: "otras", valor: otras.doble, color: Theme.gris, nombre: "Otras"))
        }
        return lista
    }
}

// MARK: - Hoja "¿Cómo se calcula?"

/// Explica de dónde sale la cifra de "Hoy puedes gastar", paso a paso.
private struct HojaComoSeCalcula: View {
    let resultado: ResultadoHoy
    let explicacion: String

    @Environment(\.dismiss) private var cerrar

    private var hasta: String {
        if let ingreso = resultado.proximoIngreso {
            return "Hasta que llegue \(ingreso.nombre)"
        }
        return "Hasta fin de mes"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Espacio.l) {
                    Text(explicacion)
                        .font(.body)
                        .foregroundStyle(Theme.texto)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 0) {
                        fila(numero: 1, titulo: "Plata libre", detalle: "Lo que tienes fuera de cajitas") {
                            CifraPlata(valor: resultado.libre)
                        }
                        SeparadorFila(sangria: 56)
                        fila(numero: 2, titulo: "Apartas para pagos", detalle: "Lo que vence antes del próximo ingreso") {
                            CifraPlata(valor: resultado.pagosAntes, signo: .salida)
                        }
                        SeparadorFila(sangria: 56)
                        fila(numero: 3, titulo: "Lo repartes en",
                             detalle: hasta) {
                            Text(resultado.dias == 1 ? "1 día" : "\(resultado.dias) días")
                                .font(.cifra)
                                .monospacedDigit()
                                .foregroundStyle(Theme.texto)
                        }
                    }
                    .panel(padding: 0)

                    VStack(spacing: 0) {
                        filaSimple("Te toca hoy") {
                            CifraPlata(valor: resultado.permitido)
                        }
                        SeparadorFila(sangria: Espacio.m)
                        filaSimple("Ya gastaste hoy") {
                            CifraPlata(valor: resultado.gastadoHoy, signo: resultado.gastadoHoy > 0 ? .salida : .ninguno)
                        }
                        SeparadorFila(sangria: Espacio.m)
                        filaSimple(resultado.disponible < 0 ? "Te pasaste" : "Te queda hoy", destacada: true) {
                            CifraPlata(valor: resultado.disponible, estilo: .media)
                        }
                    }
                    .panel(padding: 0)

                    if resultado.mandaPresupuesto {
                        Text("Hoy manda tu presupuesto del mes porque es más bajo que lo que te alcanza con tu plata.")
                            .font(.footnote)
                            .foregroundStyle(Theme.gris)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Espacio.margen)
                .padding(.top, Espacio.xs)
                .padding(.bottom, Espacio.xl)
            }
            .background(Theme.fondo.ignoresSafeArea())
            .navigationTitle("¿Cómo se calcula?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { cerrar() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func fila<Derecha: View>(numero: Int, titulo: String, detalle: String,
                                     @ViewBuilder derecha: () -> Derecha) -> some View {
        HStack(spacing: Espacio.s) {
            Text("\(numero)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.acento)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.acentoSuave))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.texto)
                Text(detalle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.gris)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            derecha()
        }
        .padding(.horizontal, Espacio.m)
        .padding(.vertical, Espacio.s)
        .frame(minHeight: 60)
        .accessibilityElement(children: .combine)
    }

    private func filaSimple<Derecha: View>(_ titulo: String, destacada: Bool = false,
                                           @ViewBuilder derecha: () -> Derecha) -> some View {
        HStack(spacing: Espacio.s) {
            Text(titulo)
                .font(destacada ? Font.body.weight(.semibold) : Font.body)
                .foregroundStyle(Theme.texto)
            Spacer(minLength: Espacio.xs)
            derecha()
        }
        .padding(.horizontal, Espacio.m)
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }
}

/// Construye la hoja de "¿cuánto fue de verdad?" para una obligación.
func solicitudPara(_ obligacion: Obligacion, store: FinanceStore) -> SolicitudValor {
    SolicitudValor(
        titulo: obligacion.nombre,
        pregunta: obligacion.tipo == .pago ? "¿Cuánto pagaste de verdad?" : "¿Cuánto te llegó?",
        montoSugerido: obligacion.monto,
        fechaSugerida: Date()
    ) { monto, fecha in
        store.registrar(obligacion, monto: monto, fecha: fecha)
    }
}
