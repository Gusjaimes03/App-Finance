import Foundation

/// Las "pruebas mínimas" de la especificación, corriendo sobre datos de mentira.
/// Sirven para comprobar que las cuentas dan lo que deben después de cada cambio.
struct Autoprueba: Identifiable {
    let id = UUID()
    let nombre: String
    let pasa: Bool
    let detalle: String
}

enum Autopruebas {

    static func correr() -> [Autoprueba] {
        [
            pruebaPlataLibre(),
            pruebaHoyPuedesGastar(),
            pruebaCuotaConExceso(),
            pruebaCuotaSinPremio(),
            pruebaFijoPorMenos(),
            pruebaPagoDeTarjeta(),
            pruebaGastoConCredito(),
            pruebaAbonoParcial(),
            pruebaPrestamoRecibido(),
            pruebaSuscripcionEnDolares(),
            pruebaEditarAbonoDeDeuda(),
            pruebaEditarAbonoDeCobro()
        ]
    }

    // MARK: Utilidades

    private static func tienda(_ ajustar: (inout AppData) -> Void = { _ in }) -> FinanceStore {
        var datos = AppData(
            inicio: Semilla.fecha(2026, 11, 6),
            trm: 3235.59,
            categorias: Semilla.categorias,
            fijos: Semilla.fijos,
            gastos: [],
            agenda: [],
            pagosFijos: [],
            cajitas: [],
            deudas: Semilla.deudas
        )
        ajustar(&datos)
        return FinanceStore(datosDePrueba: datos)
    }

    private static func ingresoHecho(_ monto: Decimal, _ dia: Int) -> AgendaItem {
        AgendaItem(
            tipo: .ingreso,
            nombre: "Sueldo de prueba",
            monto: monto,
            fecha: Semilla.fecha(2026, 11, dia),
            hecho: true,
            hechoMonto: monto,
            hechoFecha: Semilla.fecha(2026, 11, dia)
        )
    }

    private static func pagoHecho(_ monto: Decimal, _ dia: Int) -> AgendaItem {
        AgendaItem(
            tipo: .pago,
            nombre: "Pago de prueba",
            monto: monto,
            fecha: Semilla.fecha(2026, 11, dia),
            hecho: true,
            hechoMonto: monto,
            hechoFecha: Semilla.fecha(2026, 11, dia)
        )
    }

    private static func resultado(_ nombre: String, _ obtenido: Decimal, _ esperado: Decimal) -> Autoprueba {
        Autoprueba(
            nombre: nombre,
            pasa: obtenido == esperado,
            detalle: obtenido == esperado
                ? Fmt.plata(esperado)
                : "esperaba \(Fmt.plata(esperado)) y dio \(Fmt.plata(obtenido))"
        )
    }

    // MARK: Pruebas

    /// 1. Plata libre = ingresos − pagos − gastos con débito.
    static func pruebaPlataLibre() -> Autoprueba {
        let store = tienda { datos in
            datos.agenda = [ingresoHecho(1_966_855, 8), pagoHecho(1_489_000, 8)]
            datos.gastos = [Gasto(monto: 408_500, cat: "comida", fecha: Semilla.fecha(2026, 11, 8))]
        }
        return resultado("Plata libre", store.libre, 69_355)
    }

    /// 2. El 10 de noviembre, con el próximo ingreso el 16: $69.355 / 6 días.
    static func pruebaHoyPuedesGastar() -> Autoprueba {
        let store = tienda { datos in
            datos.agenda = [
                ingresoHecho(1_966_855, 8),
                pagoHecho(1_489_000, 8),
                AgendaItem(tipo: .ingreso, nombre: "Próximo sueldo", monto: 1_400_000, fecha: Semilla.fecha(2026, 11, 16))
            ]
            datos.gastos = [Gasto(monto: 408_500, cat: "comida", fecha: Semilla.fecha(2026, 11, 8))]
        }
        let hoy = store.hoyPuedesGastar(hoy: Semilla.fecha(2026, 11, 10))
        return resultado("Hoy puedes gastar", hoy.disponible, 11_559)
    }

    /// Cuota fija: $1.200.000 al mes en noviembre = $40.000 diarios. Gastar $100.000 el 10
    /// deja $60.000 de más, que se reparten en los 20 días que quedan: el 11 la cuota es $37.000.
    static func pruebaCuotaConExceso() -> Autoprueba {
        let store = tienda { datos in
            datos.agenda = [ingresoHecho(5_000_000, 6)]
            datos.gastos = [Gasto(monto: 100_000, cat: "comida", fecha: Semilla.fecha(2026, 11, 10))]
        }
        let hoy = store.hoyPuedesGastar(hoy: Semilla.fecha(2026, 11, 11))
        return resultado("Cuota diaria con un día de más", hoy.disponible, 37_000)
    }

    /// Gastar de menos no sube la cuota: con $10.000 el 10, el 11 sigue en $40.000.
    static func pruebaCuotaSinPremio() -> Autoprueba {
        let store = tienda { datos in
            datos.agenda = [ingresoHecho(5_000_000, 6)]
            datos.gastos = [Gasto(monto: 10_000, cat: "comida", fecha: Semilla.fecha(2026, 11, 10))]
        }
        let hoy = store.hoyPuedesGastar(hoy: Semilla.fecha(2026, 11, 11))
        return resultado("Cuota diaria sin premio por gastar menos", hoy.disponible, 40_000)
    }

    /// 3. Pagar un fijo por menos: se guarda el real y se muestra el ahorro.
    static func pruebaFijoPorMenos() -> Autoprueba {
        let store = tienda { datos in
            datos.agenda = [ingresoHecho(1_000_000, 7)]
        }
        guard let servicios = store.fijo("servicios") else {
            return Autoprueba(nombre: "Fijo pagado por menos", pasa: false, detalle: "falta el fijo de servicios")
        }
        let antes = store.libre
        store.pagarFijo(servicios, periodo: "2026-11", monto: 150_000, fecha: Semilla.fecha(2026, 11, 10))
        let pago = store.pagoDeFijo("servicios", periodo: "2026-11")
        let bajo = antes - store.libre
        let pasa = bajo == 150_000 && pago?.ahorro == 50_000
        return Autoprueba(
            nombre: "Fijo pagado por menos",
            pasa: pasa,
            detalle: pasa
                ? "bajó $ 150.000 y ahorró $ 50.000"
                : "bajó \(Fmt.plata(bajo)) y ahorró \(Fmt.plata(pago?.ahorro ?? 0))"
        )
    }

    /// 4. Pagar la tarjeta deja la deuda en 0 y deshacer la devuelve.
    static func pruebaPagoDeTarjeta() -> Autoprueba {
        let store = tienda()
        guard let guamacard = store.fijo("guamacard") else {
            return Autoprueba(nombre: "Pago de la tarjeta", pasa: false, detalle: "falta el fijo de la tarjeta")
        }
        store.pagarFijo(guamacard, periodo: "2026-11", monto: 400_000, fecha: Semilla.fecha(2026, 11, 25))
        let enCero = store.deuda("guamacard")?.saldo ?? -1

        if let pago = store.pagoDeFijo("guamacard", periodo: "2026-11") {
            store.deshacerPagoFijo(pago)
        }
        let devuelta = store.deuda("guamacard")?.saldo ?? -1
        let pasa = enCero == 0 && devuelta == 400_000
        return Autoprueba(
            nombre: "Pago de la tarjeta",
            pasa: pasa,
            detalle: pasa ? "queda en $ 0 y vuelve a $ 400.000"
                          : "quedó en \(Fmt.plata(enCero)) y volvió a \(Fmt.plata(devuelta))"
        )
    }

    /// 5. Un gasto con crédito no baja la plata libre y sube la deuda.
    static func pruebaGastoConCredito() -> Autoprueba {
        let store = tienda { datos in
            datos.agenda = [ingresoHecho(1_000_000, 7)]
        }
        let antes = store.libre
        store.agregarGasto(monto: 12_000, cat: "comida", metodo: .credito, nota: "prueba", fecha: Semilla.fecha(2026, 11, 10))
        let deuda = store.deuda("guamacard")?.saldo ?? 0
        let pasa = store.libre == antes && deuda == 412_000
        return Autoprueba(
            nombre: "Gasto con Guamacard",
            pasa: pasa,
            detalle: pasa ? "la plata libre no se movió y la deuda quedó en $ 412.000"
                          : "libre \(Fmt.plata(store.libre)) y deuda \(Fmt.plata(deuda))"
        )
    }

    /// 6. "Me pagó" parcial baja el cobro; borrar el abono lo devuelve.
    static func pruebaAbonoParcial() -> Autoprueba {
        let cobro = AgendaItem(
            tipo: .ingreso,
            nombre: "Mamá",
            monto: 500_000,
            porCobrar: true,
            persona: "Mamá",
            montoOriginal: 500_000
        )
        let store = tienda { datos in datos.agenda = [cobro] }
        store.registrarCobro(cobro, monto: 200_000, fecha: Semilla.fecha(2026, 11, 10))
        let pendiente = store.data.agenda.first { $0.id == cobro.id }?.monto ?? 0

        guard let abono = store.data.agenda.first(where: { $0.cobroId == cobro.id }) else {
            return Autoprueba(nombre: "Abono parcial", pasa: false, detalle: "no se creó el ingreso del abono")
        }
        store.quitarAgenda(abono)
        let devuelto = store.data.agenda.first { $0.id == cobro.id }?.monto ?? 0
        let pasa = pendiente == 300_000 && devuelto == 500_000
        return Autoprueba(
            nombre: "Abono parcial",
            pasa: pasa,
            detalle: pasa ? "queda en $ 300.000 y al borrarlo vuelve a $ 500.000"
                          : "quedó en \(Fmt.plata(pendiente)) y volvió a \(Fmt.plata(devuelto))"
        )
    }

    /// 7. La plata prestada que entra no es sueldo.
    static func pruebaPrestamoRecibido() -> Autoprueba {
        let store = tienda { datos in
            datos.agenda = [
                AgendaItem(
                    tipo: .ingreso,
                    nombre: "Préstamo recibido",
                    monto: 400_000,
                    fecha: Semilla.fecha(2026, 11, 9),
                    hecho: true,
                    hechoMonto: 400_000,
                    hechoFecha: Semilla.fecha(2026, 11, 9),
                    prestamo: true
                )
            ]
        }
        let resumen = store.resumen(mes: Semilla.fecha(2026, 11, 1))
        let pasa = resumen.sueldosReal == 0 && resumen.prestadaReal == 400_000
        return Autoprueba(
            nombre: "Plata prestada",
            pasa: pasa,
            detalle: pasa ? "no cuenta como sueldo"
                          : "sueldos \(Fmt.plata(resumen.sueldosReal)), prestada \(Fmt.plata(resumen.prestadaReal))"
        )
    }

    /// 9. Suscripción en dólares: USD 100 × 3.235,59.
    static func pruebaSuscripcionEnDolares() -> Autoprueba {
        let store = tienda()
        guard let claude = store.fijo("s_claude") else {
            return Autoprueba(nombre: "Suscripción en dólares", pasa: false, detalle: "falta la suscripción")
        }
        return resultado("Suscripción en dólares", store.montoFijo(claude) ?? 0, 323_559)
    }

    // MARK: Editar y borrar

    /// 9. Corregir un abono a una deuda ajusta el saldo; borrarlo lo devuelve y deshacer lo vuelve a bajar.
    static func pruebaEditarAbonoDeDeuda() -> Autoprueba {
        let store = tienda()
        guard let monet = store.deuda("monet") else {
            return Autoprueba(nombre: "Editar abono de deuda", pasa: false, detalle: "falta la deuda de prueba")
        }
        store.abonarDeuda(monet, monto: 100_000, fecha: Semilla.fecha(2026, 11, 10))
        guard var abono = store.data.agenda.first(where: { $0.abono && $0.deudaId == "monet" }) else {
            return Autoprueba(nombre: "Editar abono de deuda", pasa: false, detalle: "no se creó el abono")
        }
        abono.hechoMonto = 150_000
        abono.monto = 150_000
        store.actualizarAgenda(abono)
        let corregido = store.deuda("monet")?.saldo ?? -1
        let deshacer = store.borrarAgenda(abono)
        let borrado = store.deuda("monet")?.saldo ?? -1
        deshacer()
        let rehecho = store.deuda("monet")?.saldo ?? -1
        let pasa = corregido == 292_000 && borrado == 442_000 && rehecho == 292_000
        return Autoprueba(
            nombre: "Editar abono de deuda",
            pasa: pasa,
            detalle: pasa ? "queda en $ 292.000, al borrarlo vuelve a $ 442.000 y deshacer lo baja otra vez"
                          : "quedó en \(Fmt.plata(corregido)), \(Fmt.plata(borrado)) y \(Fmt.plata(rehecho))"
        )
    }

    /// 10. Corregir el abono de un cobro cambia lo que te deben por la diferencia.
    static func pruebaEditarAbonoDeCobro() -> Autoprueba {
        let cobro = AgendaItem(
            tipo: .ingreso, nombre: "Mamá", monto: 500_000,
            porCobrar: true, persona: "Mamá", montoOriginal: 500_000
        )
        let store = tienda { datos in datos.agenda = [cobro] }
        store.registrarCobro(cobro, monto: 200_000, fecha: Semilla.fecha(2026, 11, 10))
        guard var abono = store.data.agenda.first(where: { $0.cobroId == cobro.id }) else {
            return Autoprueba(nombre: "Editar abono de cobro", pasa: false, detalle: "no se creó el abono")
        }
        abono.hechoMonto = 250_000
        abono.monto = 250_000
        store.actualizarAgenda(abono)
        let pendiente = store.data.agenda.first { $0.id == cobro.id }?.monto ?? 0
        let pasa = pendiente == 250_000
        return Autoprueba(
            nombre: "Editar abono de cobro",
            pasa: pasa,
            detalle: pasa ? "te queda debiendo $ 250.000" : "quedó en \(Fmt.plata(pendiente))"
        )
    }
}
