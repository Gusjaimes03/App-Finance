import Foundation

// MARK: - Resultados

/// Todo lo que necesita la tarjeta "Hoy puedes gastar" (regla 4.3).
struct ResultadoHoy {
    var permitido: Decimal = 0
    var gastadoHoy: Decimal = 0
    var disponible: Decimal = 0
    var libre: Decimal = 0
    var pagosAntes: Decimal = 0
    var dias: Int = 1
    var limite: Date = Date()
    var proximoIngreso: Obligacion?
    /// `true` si manda el presupuesto y no la plata disponible.
    var mandaPresupuesto: Bool = false
}

/// Columnas Presupuesto | Real hasta hoy (regla 4.4).
struct ResumenMes {
    var sueldosPresupuesto: Decimal = 0
    var sueldosReal: Decimal = 0
    var extras: Decimal = 0
    var prestadaPresupuesto: Decimal = 0
    var prestadaReal: Decimal = 0
    var fijosPresupuesto: Decimal = 0
    var fijosReal: Decimal = 0
    var ahorroFijos: Decimal = 0
    var unicosPresupuesto: Decimal = 0
    var unicosReal: Decimal = 0
    var diaADiaPresupuesto: Decimal = 0
    var diaADiaReal: Decimal = 0

    var resultadoPresupuesto: Decimal {
        sueldosPresupuesto + extras + prestadaPresupuesto - fijosPresupuesto - unicosPresupuesto - diaADiaPresupuesto
    }

    var resultadoReal: Decimal {
        sueldosReal + extras + prestadaReal - fijosReal - unicosReal - diaADiaReal
    }

    var usadoDiaADia: Double {
        diaADiaPresupuesto > 0 ? diaADiaReal.doble / diaADiaPresupuesto.doble : 0
    }
}

struct TotalCategoria: Identifiable {
    let categoria: Categoria
    let total: Decimal
    let cantidad: Int
    let parte: Double

    var id: String { categoria.id }
}

struct TotalDia: Identifiable {
    let fecha: Date
    let total: Decimal

    var id: Date { fecha }
}

/// Franja del día (regla: Mañana 5–11, Mediodía 11–14, Tarde 14–18, Noche 18–5).
struct Franja: Identifiable {
    let nombre: String
    let desde: Int
    let hasta: Int
    var total: Decimal = 0
    var cantidad: Int = 0
    var masComun: String?

    var id: String { nombre }

    static let todas: [Franja] = [
        Franja(nombre: "Mañana", desde: 5, hasta: 11),
        Franja(nombre: "Mediodía", desde: 11, hasta: 14),
        Franja(nombre: "Tarde", desde: 14, hasta: 18),
        Franja(nombre: "Noche", desde: 18, hasta: 5)
    ]

    func contiene(_ hora: Double) -> Bool {
        if desde < hasta { return hora >= Double(desde) && hora < Double(hasta) }
        return hora >= Double(desde) || hora < Double(hasta)
    }
}

// MARK: - Cálculos

extension FinanceStore {

    // MARK: 4.1 Saldo y plata libre

    /// Plata que hay en total, contando solo lo que ya pasó.
    var saldo: Decimal {
        var total: Decimal = 0
        for item in data.agenda where item.hecho {
            let valor = item.hechoMonto ?? item.monto
            total += item.tipo == .ingreso ? valor : -valor
        }
        for pago in data.pagosFijos {
            total -= pago.monto
        }
        for gasto in data.gastos where gasto.metodo != .credito && gasto.fecha >= data.inicio.inicioDeDia {
            total -= gasto.monto
        }
        return total
    }

    var enCajitas: Decimal {
        data.cajitas.reduce(Decimal.zero) { $0 + $1.guardado }
    }

    /// Lo que puede gastar sin tocar las cajitas.
    var libre: Decimal { saldo - enCajitas }

    // MARK: Consultas de gastos

    func gastos(enMes mes: Date) -> [Gasto] {
        data.gastos.filter { $0.fecha.mismoMes(que: mes) }
    }

    func gastos(enDia dia: Date) -> [Gasto] {
        data.gastos.filter { $0.fecha.mismoDia(que: dia) }
    }

    var gastadoHoy: Decimal { gastado(enDia: Date()) }

    func gastado(enDia dia: Date) -> Decimal {
        gastos(enDia: dia).reduce(Decimal.zero) { $0 + $1.monto }
    }

    func gastadoDebito(enDia dia: Date) -> Decimal {
        gastos(enDia: dia)
            .filter { $0.metodo != .credito }
            .reduce(Decimal.zero) { $0 + $1.monto }
    }

    /// Gastado de lunes a hoy.
    var gastadoEstaSemana: Decimal {
        let hoy = Date().inicioDeDia
        var calendario = Calendar.app
        calendario.firstWeekday = 2 // lunes
        let inicioSemana = calendario.dateInterval(of: .weekOfYear, for: hoy)?.start ?? hoy
        return data.gastos
            .filter { $0.fecha >= inicioSemana && $0.fecha <= hoy }
            .reduce(Decimal.zero) { $0 + $1.monto }
    }

    // MARK: 4.2 Obligaciones

    func estado(de fecha: Date?, hoy: Date = Date().inicioDeDia) -> EstadoObligacion {
        guard let fecha else { return .sinFecha }
        if fecha < hoy { return .vencido }
        if fecha.dias(desde: hoy) <= 7 { return .pronto }
        if fecha.mismoMes(que: hoy) { return .mes }
        return .despues
    }

    /// Meses (como primer día) entre dos fechas, incluidos los extremos.
    func meses(desde: Date, hasta: Date) -> [Date] {
        var lista: [Date] = []
        var cursor = desde.inicioDeMes
        let tope = hasta.inicioDeMes
        var guarda = 0
        while cursor <= tope && guarda < 240 {
            lista.append(cursor)
            cursor = cursor.sumandoMeses(1)
            guarda += 1
        }
        return lista
    }

    /// Fecha en la que cae un fijo dentro de un mes (ajustada al último día).
    func fechaDeFijo(_ fijo: Fijo, mes: Date) -> Date? {
        guard let dia = fijo.dia else { return nil }
        let ultimo = mes.diasDelMes
        var partes = Calendar.app.dateComponents([.year, .month], from: mes)
        partes.day = min(dia, ultimo)
        return Calendar.app.date(from: partes)
    }

    /// Todo lo que está pendiente: agenda + un pago por mes de cada fijo con aviso.
    func obligaciones(incluyendoCobros: Bool = false, hoy fechaBase: Date = Date()) -> [Obligacion] {
        let hoy = fechaBase.inicioDeDia
        var lista: [Obligacion] = []

        for item in data.agenda where !item.hecho {
            if item.porCobrar && !incluyendoCobros { continue }
            lista.append(
                Obligacion(
                    id: item.id.uuidString,
                    tipo: item.tipo,
                    nombre: item.nombre,
                    monto: item.monto,
                    fecha: item.fecha,
                    fechaTexto: item.fechaTexto,
                    nota: item.nota,
                    simbolo: item.simbolo,
                    estado: estado(de: item.fecha, hoy: hoy),
                    agendaId: item.id,
                    deudaId: item.deudaId,
                    porCobrar: item.porCobrar,
                    persona: item.persona
                )
            )
        }

        let desde = data.inicio.inicioDeMes
        let hasta = hoy.inicioDeMes.sumandoMeses(1)
        for fijo in data.fijos where fijo.aviso {
            for mes in meses(desde: desde, hasta: hasta) {
                let periodo = mes.clavePeriodo
                guard fijo.aplicaEn(periodo: periodo) else { continue }
                guard pagoDeFijo(fijo.id, periodo: periodo) == nil else { continue }
                let fecha = fechaDeFijo(fijo, mes: mes)
                lista.append(
                    Obligacion(
                        id: "\(fijo.id)_\(periodo)",
                        tipo: .pago,
                        nombre: fijo.nombre,
                        monto: montoFijo(fijo) ?? 0,
                        fecha: fecha,
                        fechaTexto: nil,
                        nota: fijo.nota,
                        simbolo: fijo.simbolo,
                        estado: estado(de: fecha, hoy: hoy),
                        fijoId: fijo.id,
                        periodo: periodo,
                        deudaId: fijo.deudaId,
                        porCobrar: false
                    )
                )
            }
        }

        return lista.sorted { izq, der in
            if izq.estado.orden != der.estado.orden { return izq.estado.orden < der.estado.orden }
            switch (izq.fecha, der.fecha) {
            case let (i?, d?): return i < d
            case (nil, _): return false
            case (_, nil): return true
            }
        }
    }

    /// Cuánto de una obligación ya está cubierto por una cajita.
    func cubiertoPorCajitas(_ obligacion: Obligacion) -> Decimal {
        data.cajitas
            .filter { cajita in
                guard let para = cajita.para else { return false }
                return para == obligacion.fijoId || para == obligacion.agendaId?.uuidString
            }
            .reduce(Decimal.zero) { $0 + $1.guardado }
    }

    // MARK: 4.3 Hoy puedes gastar

    /// `hoy` se puede fijar para las autopruebas.
    func hoyPuedesGastar(hoy fechaBase: Date = Date()) -> ResultadoHoy {
        let hoy = fechaBase.inicioDeDia
        let pendientes = obligaciones(hoy: hoy)

        let proximo = pendientes
            .filter { $0.tipo == .ingreso && !$0.porCobrar }
            .filter { ($0.fecha ?? .distantPast) > hoy }
            .min { ($0.fecha ?? .distantFuture) < ($1.fecha ?? .distantFuture) }

        let limite = proximo?.fecha ?? hoy.finDeMes.sumandoDias(1)
        let dias = max(1, limite.dias(desde: hoy))

        let pagosAntes = pendientes
            .filter { $0.tipo == .pago }
            .filter { ($0.fecha ?? .distantFuture) < limite }
            .reduce(Decimal.zero) { suma, obligacion in
                suma + max(0, obligacion.monto - cubiertoPorCajitas(obligacion))
            }

        let porPlata = max(0, libre + gastadoDebito(enDia: hoy) - pagosAntes) / Decimal(dias)

        let presupuestoMes = presupuestoDiaADia(mes: hoy)
        let gastadoAntes = gastos(enMes: hoy)
            .filter { $0.fecha < hoy }
            .reduce(Decimal.zero) { $0 + $1.monto }
        let diasQueQuedan = max(1, hoy.diasDelMes - hoy.diaDelMes + 1)
        let porPresupuesto = max(0, (presupuestoMes - gastadoAntes) / Decimal(diasQueQuedan))

        let hayPresupuesto = presupuestoMes > 0
        let permitido = hayPresupuesto ? min(porPresupuesto, porPlata) : porPlata
        let gastadoDelDia = gastado(enDia: hoy)

        return ResultadoHoy(
            permitido: permitido.redondeado,
            gastadoHoy: gastadoDelDia,
            disponible: (permitido - gastadoDelDia).redondeado,
            libre: libre,
            pagosAntes: pagosAntes,
            dias: dias,
            limite: limite,
            proximoIngreso: proximo,
            mandaPresupuesto: hayPresupuesto && porPresupuesto < porPlata
        )
    }

    // MARK: 4.4 Presupuesto del mes

    /// Parte del mes en la que ya se registra (si empezó el 6, noviembre cuenta 25/30).
    func factorDias(mes: Date) -> Decimal {
        let inicioMes = mes.inicioDeMes
        let total = mes.diasDelMes
        let desde = max(inicioMes, data.inicio.inicioDeDia)
        guard desde <= mes.finDeMes else { return 0 }
        let activos = mes.finDeMes.dias(desde: desde) + 1
        return Decimal(min(max(activos, 0), total)) / Decimal(total)
    }

    func presupuestoDiaADia(mes: Date) -> Decimal {
        let suma = categoriasVisibles.reduce(Decimal.zero) { $0 + $1.mensual }
        return (suma * factorDias(mes: mes)).redondeado
    }

    func presupuestoCategoria(_ categoria: Categoria, mes: Date) -> Decimal {
        (categoria.mensual * factorDias(mes: mes)).redondeado
    }

    func resumen(mes: Date) -> ResumenMes {
        var r = ResumenMes()
        let periodo = mes.clavePeriodo

        for item in data.agenda {
            guard let mesItem = item.mesContable, mesItem.mismoMes(que: mes) else { continue }
            let valor = item.valorEfectivo

            if item.esSueldo {
                r.sueldosPresupuesto += valor
                if item.hecho { r.sueldosReal += valor }
            } else if item.tipo == .ingreso && item.prestamo {
                r.prestadaPresupuesto += valor
                if item.hecho { r.prestadaReal += valor }
            } else if item.tipo == .ingreso && item.hecho && (item.extra || item.cobroId != nil || item.porCobrar) {
                r.extras += valor
            } else if item.tipo == .pago {
                r.unicosPresupuesto += valor
                if item.hecho { r.unicosReal += valor }
            }
        }

        for fijo in data.fijos where fijo.cuenta && fijo.aplicaEn(periodo: periodo) {
            if let pago = pagoDeFijo(fijo.id, periodo: periodo) {
                r.fijosPresupuesto += pago.monto
                r.fijosReal += pago.monto
                r.ahorroFijos += pago.ahorro
            } else {
                r.fijosPresupuesto += montoFijo(fijo) ?? 0
            }
        }

        r.diaADiaPresupuesto = presupuestoDiaADia(mes: mes)
        r.diaADiaReal = gastos(enMes: mes).reduce(Decimal.zero) { $0 + $1.monto }
        return r
    }

    /// Avisa si un sueldo del mes llega en los últimos días.
    func sueldoTardio(mes: Date) -> AgendaItem? {
        data.agenda.first { item in
            guard item.esSueldo, let fecha = item.mesContable, fecha.mismoMes(que: mes) else { return false }
            return fecha.diaDelMes >= mes.diasDelMes - 2
        }
    }

    // MARK: Desgloses

    func totalesPorCategoria(mes: Date) -> [TotalCategoria] {
        let lista = gastos(enMes: mes)
        let total = lista.reduce(Decimal.zero) { $0 + $1.monto }
        guard total > 0 else { return [] }

        var cubos: [String: (Decimal, Int)] = [:]
        for gasto in lista {
            var cubo = cubos[gasto.cat] ?? (0, 0)
            cubo.0 += gasto.monto
            cubo.1 += 1
            cubos[gasto.cat] = cubo
        }

        return cubos
            .map { id, cubo in
                TotalCategoria(
                    categoria: categoria(id),
                    total: cubo.0,
                    cantidad: cubo.1,
                    parte: cubo.0.doble / total.doble
                )
            }
            .sorted { $0.total > $1.total }
    }

    func totalesPorDia(mes: Date) -> [TotalDia] {
        let dias = mes.diasDelMes
        let inicio = mes.inicioDeMes
        let porDia = Dictionary(grouping: gastos(enMes: mes)) { $0.fecha.inicioDeDia }
        return (0..<dias).map { indice in
            let fecha = inicio.sumandoDias(indice)
            let total = (porDia[fecha.inicioDeDia] ?? []).reduce(Decimal.zero) { $0 + $1.monto }
            return TotalDia(fecha: fecha, total: total)
        }
    }

    /// Presupuesto por día para la línea punteada de las barras.
    func presupuestoDiario(mes: Date) -> Decimal {
        let total = categoriasVisibles.reduce(Decimal.zero) { $0 + $1.mensual }
        return (total / Decimal(mes.diasDelMes)).redondeado
    }

    func franjas(mes: Date) -> (franjas: [Franja], sinHora: Int) {
        var resultado = Franja.todas
        var sinHora = 0
        var comunes: [String: [String: Decimal]] = [:]

        for gasto in gastos(enMes: mes) {
            guard let hora = gasto.horaDecimal else {
                sinHora += 1
                continue
            }
            guard let indice = resultado.firstIndex(where: { $0.contiene(hora) }) else { continue }
            resultado[indice].total += gasto.monto
            resultado[indice].cantidad += 1
            let nombre = categoria(gasto.cat).nombre
            comunes[resultado[indice].nombre, default: [:]][nombre, default: 0] += gasto.monto
        }

        for indice in resultado.indices {
            resultado[indice].masComun = comunes[resultado[indice].nombre]?
                .max { $0.value < $1.value }?.key
        }
        return (resultado, sinHora)
    }

    // MARK: Balance

    var cobrosPendientes: [AgendaItem] {
        data.agenda.filter { $0.porCobrar && !$0.hecho }
    }

    var totalMeDeben: Decimal {
        cobrosPendientes.reduce(Decimal.zero) { $0 + $1.monto }
    }

    var totalDebo: Decimal {
        data.deudas.reduce(Decimal.zero) { $0 + $1.saldo }
    }

    var valorDeBienes: Decimal {
        data.deudas.reduce(Decimal.zero) { $0 + ($1.valorBien ?? 0) }
    }

    /// Lo tuyo, en plata.
    var patrimonio: Decimal {
        libre + enCajitas + totalMeDeben + valorDeBienes - totalDebo
    }

    // MARK: Avisos de la pantalla de inicio

    func avisos() -> [String] {
        var lista: [String] = []
        if libre < 0 {
            lista.append("Tu plata libre está en \(Fmt.plata(libre)). Revisa los pagos registrados.")
        }

        let resultado = hoyPuedesGastar()
        if resultado.pagosAntes > max(0, resultado.libre) {
            lista.append("No te alcanza para los pagos antes de que llegue el próximo ingreso: faltan \(Fmt.plata(resultado.pagosAntes - max(0, resultado.libre))).")
        }

        for total in totalesPorCategoria(mes: Date()) {
            let tope = presupuestoCategoria(total.categoria, mes: Date())
            if tope > 0 && total.total > tope {
                lista.append("\(total.categoria.nombre): te pasaste \(Fmt.plata(total.total - tope)) del presupuesto.")
            }
        }
        return lista
    }
}
