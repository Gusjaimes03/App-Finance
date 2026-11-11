import Foundation
import SwiftUI

/// Única fuente de verdad: guarda todo en el teléfono y aplica los enlaces
/// automáticos entre gastos, pagos, cobros y deudas (regla 4.5).
final class FinanceStore: ObservableObject {
    @Published var data: AppData
    /// Mensaje corto que se muestra abajo (toast).
    @Published var aviso: String?

    private let persistencia: Persistencia

    init(persistencia: Persistencia = .shared) {
        // Con -datosDeEjemplo 1 la app arranca con datos de mentira en su propio
        // archivo, sin tocar los reales. Sirve para las capturas automáticas.
        if UserDefaults.standard.bool(forKey: "datosDeEjemplo") {
            self.persistencia = Persistencia(nombre: "ejemplo.json")
            self.data = Semilla.ejemplo()
            return
        }
        self.persistencia = persistencia
        self.data = persistencia.cargar() ?? AppData()
        cargarSaldoInicialSiFalta()
        agregarCategoriasNuevas()
    }

    /// Agrega las categorías que trae la app y faltan en los datos guardados (antes de "Otros").
    /// Las que el usuario borró siguen ahí como ocultas, así que no vuelven a aparecer.
    private func agregarCategoriasNuevas() {
        let existentes = Set(data.categorias.map(\.id))
        let nuevas = Semilla.categorias.filter { !existentes.contains($0.id) }
        guard !nuevas.isEmpty else { return }
        let posicion = data.categorias.firstIndex(where: { $0.id == "otros" }) ?? data.categorias.endIndex
        data.categorias.insert(contentsOf: nuevas, at: posicion)
        try? persistencia.guardar(data)
    }

    /// Migración de una sola vez: los datos guardados antes no traían el saldo inicial.
    private func cargarSaldoInicialSiFalta() {
        guard !data.ajustes.saldoInicialCargado else { return }
        if !data.agenda.contains(where: { $0.id == Semilla.saldoInicialId }) {
            data.agenda.insert(Semilla.saldoInicial, at: 0)
        }
        data.ajustes.saldoInicialCargado = true
        try? persistencia.guardar(data)
    }

    /// Store aislado para las autopruebas: escribe en su propio archivo.
    init(datosDePrueba: AppData) {
        self.persistencia = Persistencia(nombre: "autopruebas.json")
        self.data = datosDePrueba
    }

    // MARK: Guardado

    func guardar() {
        do {
            try persistencia.guardar(data)
        } catch {
            assertionFailure("No se pudo guardar: \(error)")
        }
    }

    func avisar(_ texto: String) {
        aviso = texto
        Haptics.success()
    }

    // MARK: Catálogo

    var categoriasVisibles: [Categoria] {
        data.categorias.filter { !$0.oculta }
    }

    func categoria(_ id: String) -> Categoria {
        data.categorias.first { $0.id == id }
            ?? Categoria(id: id, nombre: "Otros", colorHex: "7b869e", simbolo: "ellipsis.circle.fill")
    }

    func fijo(_ id: String) -> Fijo? {
        data.fijos.first { $0.id == id }
    }

    func deuda(_ id: String) -> Deuda? {
        data.deudas.first { $0.id == id }
    }

    /// Valor presupuestado de un fijo, ya convertido si está en dólares.
    func montoFijo(_ fijo: Fijo) -> Decimal? {
        if let valor = fijo.montoEnPesos(trm: data.trm) { return valor }
        // Un fijo sin valor que paga una deuda sugiere el saldo pendiente.
        if let deudaId = fijo.deudaId, let deuda = deuda(deudaId) { return max(0, deuda.saldo) }
        return nil
    }

    func pagoDeFijo(_ fijoId: String, periodo: String) -> PagoFijo? {
        data.pagosFijos.first { $0.fijoId == fijoId && $0.periodo == periodo }
    }

    // MARK: Gastos

    func agregarGasto(monto: Decimal, cat: String, metodo: MetodoPago, nota: String, fecha: Date) {
        let hoy = Date()
        let esDeHoy = fecha.mismoDia(que: hoy)
        let gasto = Gasto(
            monto: monto.redondeado,
            cat: cat,
            metodo: metodo,
            nota: nota.trimmingCharacters(in: .whitespacesAndNewlines),
            fecha: fecha,
            hora: esDeHoy ? hoy.horaTexto : nil,
            creado: hoy
        )
        data.gastos.append(gasto)
        if metodo == .credito { ajustarDeuda("guamacard", delta: gasto.monto) }
        guardar()
        avisar("Gasto guardado")
    }

    func actualizarGasto(_ nuevo: Gasto) {
        guard let indice = data.gastos.firstIndex(where: { $0.id == nuevo.id }) else { return }
        let anterior = data.gastos[indice]

        // La tarjeta se ajusta por la diferencia (regla 4.5).
        if anterior.metodo == .credito { ajustarDeuda("guamacard", delta: -anterior.monto) }
        var limpio = nuevo
        limpio.monto = nuevo.monto.redondeado
        data.gastos[indice] = limpio
        if limpio.metodo == .credito { ajustarDeuda("guamacard", delta: limpio.monto) }

        guardar()
        avisar("Gasto actualizado")
    }

    func borrarGasto(_ gasto: Gasto) {
        data.gastos.removeAll { $0.id == gasto.id }
        if gasto.metodo == .credito { ajustarDeuda("guamacard", delta: -gasto.monto) }
        guardar()
        avisar("Gasto borrado")
    }

    // MARK: Agenda (pagos e ingresos)

    func agregarAgenda(_ item: AgendaItem) {
        data.agenda.append(item)
        guardar()
        avisar(item.tipo == .pago ? "Pago agregado" : "Ingreso agregado")
    }

    /// "Ya pagué" / "Ya me llegó" con el valor real.
    func marcarHecho(_ item: AgendaItem, monto: Decimal, fecha: Date) {
        guard let indice = data.agenda.firstIndex(where: { $0.id == item.id }) else { return }
        data.agenda[indice].hecho = true
        data.agenda[indice].hechoMonto = monto.redondeado
        data.agenda[indice].hechoFecha = fecha.inicioDeDia

        if let deudaId = item.deudaId, item.tipo == .pago {
            ajustarDeuda(deudaId, delta: -monto.redondeado)
        }
        guardar()
        avisar(item.tipo == .pago ? "Pago registrado" : "Ingreso registrado")
    }

    func deshacerAgenda(_ item: AgendaItem) {
        guard let indice = data.agenda.firstIndex(where: { $0.id == item.id }) else { return }
        let valor = data.agenda[indice].hechoMonto ?? data.agenda[indice].monto
        data.agenda[indice].hecho = false
        data.agenda[indice].hechoMonto = nil
        data.agenda[indice].hechoFecha = nil

        if let deudaId = item.deudaId, item.tipo == .pago {
            ajustarDeuda(deudaId, delta: valor)
        }
        guardar()
        avisar("Listo, lo dejé pendiente")
    }

    func corregirAgenda(_ item: AgendaItem, monto: Decimal) {
        guard let indice = data.agenda.firstIndex(where: { $0.id == item.id }) else { return }
        let anterior = data.agenda[indice].hechoMonto ?? data.agenda[indice].monto
        data.agenda[indice].hechoMonto = monto.redondeado

        if let deudaId = item.deudaId, item.tipo == .pago {
            ajustarDeuda(deudaId, delta: anterior - monto.redondeado)
        }
        guardar()
        avisar("Valor corregido")
    }

    func quitarAgenda(_ item: AgendaItem) {
        // Si era un abono a un cobro, se devuelve el saldo al cobro.
        if let cobroId = item.cobroId, let indice = data.agenda.firstIndex(where: { $0.id == cobroId }) {
            data.agenda[indice].monto += item.hechoMonto ?? item.monto
            data.agenda[indice].hecho = false
        }
        // Un pago hecho que bajó una deuda (abono o "Ya pagué" enlazado) le devuelve el saldo.
        if let (deudaId, efecto) = efectoEnDeuda(item) {
            ajustarDeuda(deudaId, delta: -efecto)
        }
        data.agenda.removeAll { $0.id == item.id }
        guardar()
        avisar("Borrado")
    }

    // MARK: Gastos fijos del mes

    /// "Ya pagué" un fijo, por el valor real (regla 4.6).
    func pagarFijo(_ fijo: Fijo, periodo: String, monto: Decimal, fecha: Date) {
        let presupuestado = montoFijo(fijo) ?? monto
        let pago = PagoFijo(
            fijoId: fijo.id,
            periodo: periodo,
            monto: monto.redondeado,
            fecha: fecha,
            presupuesto: presupuestado.redondeado
        )
        data.pagosFijos.removeAll { $0.id == pago.id }
        data.pagosFijos.append(pago)

        if let deudaId = fijo.deudaId { ajustarDeuda(deudaId, delta: -monto.redondeado) }
        guardar()
        avisar("Pago registrado")
    }

    func deshacerPagoFijo(_ pago: PagoFijo) {
        data.pagosFijos.removeAll { $0.id == pago.id }
        if let fijo = fijo(pago.fijoId), let deudaId = fijo.deudaId {
            ajustarDeuda(deudaId, delta: pago.monto)
        }
        guardar()
        avisar("Listo, quedó pendiente")
    }

    func corregirPagoFijo(_ pago: PagoFijo, monto: Decimal) {
        guard let indice = data.pagosFijos.firstIndex(where: { $0.id == pago.id }) else { return }
        let anterior = data.pagosFijos[indice].monto
        data.pagosFijos[indice].monto = monto.redondeado
        if let fijo = fijo(pago.fijoId), let deudaId = fijo.deudaId {
            ajustarDeuda(deudaId, delta: anterior - monto.redondeado)
        }
        guardar()
        avisar("Valor corregido")
    }

    // MARK: Cajitas

    func crearCajita(nombre: String, meta: Decimal, para: String? = nil) {
        let colores = Color.coloresNuevos
        let cajita = Cajita(
            nombre: nombre,
            meta: meta.redondeado,
            para: para,
            colorHex: colores[data.cajitas.count % colores.count],
            orden: data.cajitas.count
        )
        data.cajitas.append(cajita)
        guardar()
        avisar("Cajita creada")
    }

    func guardarEnCajita(_ cajita: Cajita, monto: Decimal) {
        guard let indice = data.cajitas.firstIndex(where: { $0.id == cajita.id }) else { return }
        data.cajitas[indice].guardado += monto.redondeado
        guardar()
        avisar("Guardaste \(Fmt.plata(monto))")
    }

    func sacarDeCajita(_ cajita: Cajita, monto: Decimal) {
        guard let indice = data.cajitas.firstIndex(where: { $0.id == cajita.id }) else { return }
        data.cajitas[indice].guardado = max(0, data.cajitas[indice].guardado - monto.redondeado)
        guardar()
        avisar("Sacaste \(Fmt.plata(monto))")
    }

    func quitarCajita(_ cajita: Cajita) {
        data.cajitas.removeAll { $0.id == cajita.id }
        guardar()
        avisar("Los \(Fmt.plata(cajita.guardado)) vuelven a tu plata libre")
    }

    // MARK: Deudas

    func agregarDeuda(nombre: String, saldo: Decimal, cuota: Decimal?, nota: String) {
        let deuda = Deuda(
            id: "d_\(UUID().uuidString.prefix(8))",
            nombre: nombre,
            saldo: saldo.redondeado,
            original: saldo.redondeado,
            cuota: cuota,
            nota: nota,
            orden: data.deudas.count
        )
        data.deudas.append(deuda)
        guardar()
        avisar("Deuda agregada")
    }

    /// Abonar a una deuda crea un pago hecho y baja el saldo (regla 4.5).
    func abonarDeuda(_ deuda: Deuda, monto: Decimal, fecha: Date) {
        let item = AgendaItem(
            tipo: .pago,
            nombre: "Abono a \(deuda.nombre)",
            monto: monto.redondeado,
            fecha: fecha,
            hecho: true,
            hechoMonto: monto.redondeado,
            hechoFecha: fecha,
            deudaId: deuda.id,
            abono: true,
            simbolo: "arrow.down.circle.fill"
        )
        data.agenda.append(item)
        ajustarDeuda(deuda.id, delta: -monto.redondeado)
        guardar()
        avisar("Abono registrado")
    }

    func quitarDeuda(_ deuda: Deuda) {
        data.deudas.removeAll { $0.id == deuda.id }
        guardar()
        avisar("Deuda borrada")
    }

    func ajustarDeuda(_ id: String, delta: Decimal) {
        guard let indice = data.deudas.firstIndex(where: { $0.id == id }) else { return }
        data.deudas[indice].saldo = max(0, data.deudas[indice].saldo + delta)
        if data.deudas[indice].saldo > data.deudas[indice].original {
            data.deudas[indice].original = data.deudas[indice].saldo
        }
    }

    // MARK: Cobros (lo que le deben)

    /// "Me pagó": acepta abonos parciales (regla 4.5).
    func registrarCobro(_ cobro: AgendaItem, monto: Decimal, fecha: Date) {
        guard let indice = data.agenda.firstIndex(where: { $0.id == cobro.id }) else { return }
        let valor = monto.redondeado

        if valor >= data.agenda[indice].monto {
            data.agenda[indice].hecho = true
            data.agenda[indice].hechoMonto = data.agenda[indice].monto
            data.agenda[indice].hechoFecha = fecha.inicioDeDia
        } else {
            data.agenda[indice].monto -= valor
            let abono = AgendaItem(
                tipo: .ingreso,
                nombre: "Abono de \(cobro.persona ?? cobro.nombre)",
                monto: valor,
                fecha: fecha,
                hecho: true,
                hechoMonto: valor,
                hechoFecha: fecha,
                cobroId: cobro.id,
                simbolo: "arrow.down.circle.fill"
            )
            data.agenda.append(abono)
        }
        guardar()
        avisar("Entraron \(Fmt.plata(valor))")
    }

    /// "Presté plata": sale la plata y queda el cobro pendiente.
    func prestarPlata(persona: String, monto: Decimal, fecha: Date, cuandoPaga: Date?, nota: String) {
        let valor = monto.redondeado
        let salida = AgendaItem(
            tipo: .pago,
            nombre: "Préstamo a \(persona)",
            monto: valor,
            fecha: fecha,
            nota: nota.isEmpty ? nil : nota,
            hecho: true,
            hechoMonto: valor,
            hechoFecha: fecha,
            simbolo: "arrow.up.circle.fill"
        )
        let cobro = AgendaItem(
            tipo: .ingreso,
            nombre: persona,
            monto: valor,
            fecha: cuandoPaga,
            nota: nota.isEmpty ? nil : nota,
            porCobrar: true,
            persona: persona,
            montoOriginal: valor,
            simbolo: "heart.fill"
        )
        data.agenda.append(salida)
        data.agenda.append(cobro)
        guardar()
        avisar("Préstamo registrado")
    }

    // MARK: Configuración del presupuesto

    func actualizarCategoria(_ categoria: Categoria) {
        guard let indice = data.categorias.firstIndex(where: { $0.id == categoria.id }) else { return }
        data.categorias[indice] = categoria
        guardar()
    }

    func agregarCategoria(nombre: String, mensual: Decimal) {
        let colores = Color.coloresNuevos
        let propias = data.categorias.filter { $0.esDelUsuario }.count
        let categoria = Categoria(
            id: "c_\(UUID().uuidString.prefix(8))",
            nombre: nombre,
            mensual: mensual.redondeado,
            colorHex: colores[propias % colores.count],
            simbolo: "tag.fill"
        )
        data.categorias.append(categoria)
        guardar()
        avisar("Categoría agregada")
    }

    /// Borrar una categoría (propia o de las que trae la app) la oculta: sus gastos se conservan.
    func ocultarCategoria(_ categoria: Categoria) {
        guard let indice = data.categorias.firstIndex(where: { $0.id == categoria.id }) else { return }
        data.categorias[indice].oculta = true
        guardar()
        avisar("Categoría borrada")
    }

    func actualizarFijo(_ fijo: Fijo) {
        guard let indice = data.fijos.firstIndex(where: { $0.id == fijo.id }) else { return }
        data.fijos[indice] = fijo
        guardar()
    }

    func agregarFijo(nombre: String, monto: Decimal?, usd: Decimal?, dia: Int?, suscripcion: Bool) {
        let prefijo = suscripcion ? "s_" : "f_"
        let fijo = Fijo(
            id: "\(prefijo)\(UUID().uuidString.prefix(8))",
            nombre: nombre,
            monto: monto,
            usd: usd,
            dia: dia,
            grupo: suscripcion ? "suscripcion" : nil,
            simbolo: suscripcion ? "repeat.circle.fill" : "calendar"
        )
        data.fijos.append(fijo)
        guardar()
        avisar(suscripcion ? "Suscripción agregada" : "Gasto fijo agregado")
    }

    func quitarFijo(_ fijo: Fijo) {
        data.fijos.removeAll { $0.id == fijo.id }
        guardar()
        avisar("\(fijo.nombre) borrado")
    }

    func actualizarTRM(_ valor: Decimal) {
        data.trm = valor
        guardar()
    }

    func actualizarInicio(_ fecha: Date) {
        data.inicio = fecha.inicioDeDia
        guardar()
    }

    // MARK: Ajustes de la app

    func actualizarAjustes(_ ajustes: Ajustes) {
        data.ajustes = ajustes
        guardar()
    }

    // MARK: Datos

    func exportarRespaldo() throws -> URL {
        try persistencia.archivoDeRespaldo(data)
    }

    func exportarCSV() throws -> URL {
        try persistencia.archivoCSV(csv())
    }

    func importarRespaldo(_ url: URL) throws {
        data = try persistencia.importar(url)
        guardar()
        avisar("Respaldo restaurado")
    }

    func empezarDeCero() {
        data = AppData.limpio()
        guardar()
        avisar("Todo borrado")
    }

    private func csv() -> String {
        let fechaISO = DateFormatter()
        fechaISO.locale = Locale(identifier: "en_US_POSIX")
        fechaISO.timeZone = Calendar.app.timeZone
        fechaISO.dateFormat = "yyyy-MM-dd"

        func escapar(_ texto: String) -> String {
            guard texto.contains(",") || texto.contains("\"") || texto.contains("\n") else { return texto }
            return "\"" + texto.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }

        var filas = ["Fecha,Tipo,Nombre,Categoria,Metodo,Monto,Nota"]
        for gasto in data.gastos.sorted(by: { $0.fecha < $1.fecha }) {
            filas.append([
                fechaISO.string(from: gasto.fecha),
                "Gasto",
                categoria(gasto.cat).nombre,
                categoria(gasto.cat).nombre,
                gasto.metodo.tituloCorto,
                Fmt.numero(gasto.monto).replacingOccurrences(of: ".", with: ""),
                gasto.nota
            ].map(escapar).joined(separator: ","))
        }
        for item in data.agenda where item.hecho {
            filas.append([
                fechaISO.string(from: item.hechoFecha ?? item.fecha ?? item.creado),
                item.tipo == .pago ? "Pago" : "Ingreso",
                item.nombre,
                "",
                "",
                Fmt.numero(item.valorEfectivo).replacingOccurrences(of: ".", with: ""),
                item.nota ?? ""
            ].map(escapar).joined(separator: ","))
        }
        for pago in data.pagosFijos.sorted(by: { $0.fecha < $1.fecha }) {
            filas.append([
                fechaISO.string(from: pago.fecha),
                "Fijo",
                fijo(pago.fijoId)?.nombre ?? pago.fijoId,
                "",
                "",
                Fmt.numero(pago.monto).replacingOccurrences(of: ".", with: ""),
                ""
            ].map(escapar).joined(separator: ","))
        }
        return filas.joined(separator: "\n")
    }
}
