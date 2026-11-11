import Foundation

/// Editar y borrar cualquier dato, manteniendo los enlaces automáticos (regla 4.5):
/// pagos que bajan deudas, abonos que bajan lo que te deben y pagos de fijos.
extension FinanceStore {

    // MARK: Gastos

    /// Vuelve a poner un gasto borrado (la tarjeta vuelve a subir si era con crédito).
    func restaurarGasto(_ gasto: Gasto) {
        guard !data.gastos.contains(where: { $0.id == gasto.id }) else { return }
        data.gastos.append(gasto)
        if gasto.metodo == .credito { ajustarDeuda("guamacard", delta: gasto.monto) }
        guardar()
    }

    // MARK: Agenda (pagos, ingresos, cobros, abonos, extras y el saldo inicial)

    /// Cuánto movió este movimiento el saldo de su deuda (negativo: la bajó).
    func efectoEnDeuda(_ item: AgendaItem) -> (String, Decimal)? {
        guard item.hecho, item.tipo == .pago, let deudaId = item.deudaId else { return nil }
        return (deudaId, -(item.hechoMonto ?? item.monto))
    }

    /// Guarda los cambios de un movimiento de la agenda y corrige la deuda o el cobro enlazado.
    func actualizarAgenda(_ nuevo: AgendaItem, aviso: String? = "Cambios guardados") {
        guard let indice = data.agenda.firstIndex(where: { $0.id == nuevo.id }) else { return }
        let anterior = data.agenda[indice]

        var limpio = nuevo
        limpio.nombre = nuevo.nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        if limpio.nombre.isEmpty { limpio.nombre = anterior.nombre }
        limpio.monto = max(0, nuevo.monto.redondeado)
        limpio.fecha = nuevo.fecha?.inicioDeDia
        limpio.nota = nuevo.nota.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).nilSiVacio }
        limpio.fechaTexto = nuevo.fechaTexto.flatMap { $0.fechaSinTilde.nilSiVacio }
        limpio.fuente = nuevo.fuente.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).nilSiVacio }
        limpio.persona = nuevo.persona.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).nilSiVacio }
        limpio.montoOriginal = nuevo.montoOriginal.map { max(0, $0.redondeado) }
        if limpio.hecho {
            limpio.hechoMonto = max(0, (nuevo.hechoMonto ?? nuevo.monto).redondeado)
            limpio.hechoFecha = (nuevo.hechoFecha ?? nuevo.fecha ?? Date()).inicioDeDia
        } else {
            limpio.hechoMonto = nil
            limpio.hechoFecha = nil
        }

        data.agenda[indice] = limpio

        // Deuda: se deshace el efecto anterior y se aplica el nuevo.
        let antes = efectoEnDeuda(anterior)
        let despues = efectoEnDeuda(limpio)
        if let antes, let despues, antes.0 == despues.0 {
            ajustarDeuda(antes.0, delta: despues.1 - antes.1)
        } else {
            if let antes { ajustarDeuda(antes.0, delta: -antes.1) }
            if let despues { ajustarDeuda(despues.0, delta: despues.1) }
        }

        // Abono a un cobro: lo que te deben cambia por la diferencia.
        if let cobroId = limpio.cobroId, cobroId == anterior.cobroId,
           let iCobro = data.agenda.firstIndex(where: { $0.id == cobroId }) {
            let diferencia = limpio.valorEfectivo - anterior.valorEfectivo
            data.agenda[iCobro].monto = max(0, data.agenda[iCobro].monto - diferencia)
            if data.agenda[iCobro].hecho {
                data.agenda[iCobro].hechoMonto = data.agenda[iCobro].monto
            }
        }

        guardar()
        if let aviso { avisar(aviso) }
    }

    /// Vuelve a poner un movimiento borrado (para el "Deshacer" del aviso).
    func restaurarAgenda(_ item: AgendaItem) {
        guard !data.agenda.contains(where: { $0.id == item.id }) else { return }
        data.agenda.append(item)
        if let (deudaId, efecto) = efectoEnDeuda(item) {
            ajustarDeuda(deudaId, delta: efecto)
        }
        if let cobroId = item.cobroId, let iCobro = data.agenda.firstIndex(where: { $0.id == cobroId }) {
            data.agenda[iCobro].monto = max(0, data.agenda[iCobro].monto - item.valorEfectivo)
        }
        guardar()
    }

    /// Borra un movimiento y devuelve cómo deshacerlo tal cual (incluido el cobro de un abono).
    func borrarAgenda(_ item: AgendaItem) -> () -> Void {
        let cobroAntes = item.cobroId.flatMap { id in data.agenda.first { $0.id == id } }
        quitarAgenda(item)
        return { [weak self] in
            guard let self else { return }
            self.restaurarAgenda(item)
            if let cobroAntes, let indice = self.data.agenda.firstIndex(where: { $0.id == cobroAntes.id }) {
                self.data.agenda[indice] = cobroAntes
                self.guardar()
            }
        }
    }

    // MARK: Pagos de fijos

    /// Corrige el valor y la fecha de un "Ya pagué" de un fijo (la deuda enlazada se ajusta).
    func actualizarPagoFijo(_ pago: PagoFijo, monto: Decimal, fecha: Date, aviso: String? = "Pago actualizado") {
        guard let indice = data.pagosFijos.firstIndex(where: { $0.id == pago.id }) else { return }
        let anterior = data.pagosFijos[indice].monto
        let valor = max(0, monto.redondeado)
        data.pagosFijos[indice].monto = valor
        data.pagosFijos[indice].fecha = fecha.inicioDeDia
        if let fijo = fijo(pago.fijoId), let deudaId = fijo.deudaId {
            ajustarDeuda(deudaId, delta: anterior - valor)
        }
        guardar()
        if let aviso { avisar(aviso) }
    }

    func restaurarPagoFijo(_ pago: PagoFijo) {
        guard !data.pagosFijos.contains(where: { $0.id == pago.id }) else { return }
        data.pagosFijos.append(pago)
        if let fijo = fijo(pago.fijoId), let deudaId = fijo.deudaId {
            ajustarDeuda(deudaId, delta: -pago.monto)
        }
        guardar()
    }

    // MARK: Fijos y suscripciones

    /// Vuelve a poner un fijo borrado en el mismo lugar.
    func restaurarFijo(_ fijo: Fijo, en indice: Int) {
        guard !data.fijos.contains(where: { $0.id == fijo.id }) else { return }
        data.fijos.insert(fijo, at: min(max(0, indice), data.fijos.count))
        guardar()
    }

    // MARK: Categorías

    func mostrarCategoria(_ categoria: Categoria) {
        guard let indice = data.categorias.firstIndex(where: { $0.id == categoria.id }) else { return }
        data.categorias[indice].oculta = false
        guardar()
        avisar("\(categoria.nombre) volvió")
    }

    var categoriasOcultas: [Categoria] {
        data.categorias.filter { $0.oculta }
    }

    // MARK: Cajitas

    func actualizarCajita(_ nueva: Cajita, aviso: String? = "Cajita actualizada") {
        guard let indice = data.cajitas.firstIndex(where: { $0.id == nueva.id }) else { return }
        var limpia = nueva
        limpia.nombre = nueva.nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        if limpia.nombre.isEmpty { limpia.nombre = data.cajitas[indice].nombre }
        limpia.nota = nueva.nota.trimmingCharacters(in: .whitespacesAndNewlines)
        limpia.meta = max(0, nueva.meta.redondeado)
        limpia.guardado = max(0, nueva.guardado.redondeado)
        data.cajitas[indice] = limpia
        guardar()
        if let aviso { avisar(aviso) }
    }

    func restaurarCajita(_ cajita: Cajita) {
        guard !data.cajitas.contains(where: { $0.id == cajita.id }) else { return }
        data.cajitas.append(cajita)
        guardar()
    }

    // MARK: Deudas

    func actualizarDeuda(_ nueva: Deuda, aviso: String? = "Deuda actualizada") {
        guard let indice = data.deudas.firstIndex(where: { $0.id == nueva.id }) else { return }
        var limpia = nueva
        limpia.nombre = nueva.nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        if limpia.nombre.isEmpty { limpia.nombre = data.deudas[indice].nombre }
        limpia.nota = nueva.nota.trimmingCharacters(in: .whitespacesAndNewlines)
        limpia.saldo = max(0, nueva.saldo.redondeado)
        // Lo que debías al principio nunca es menos de lo que debes hoy.
        limpia.original = max(limpia.saldo, nueva.original.redondeado)
        limpia.cuota = nueva.cuota.flatMap { $0 > 0 ? $0.redondeado : nil }
        limpia.valorBien = nueva.valorBien.flatMap { $0 > 0 ? $0.redondeado : nil }
        data.deudas[indice] = limpia
        guardar()
        if let aviso { avisar(aviso) }
    }

    func restaurarDeuda(_ deuda: Deuda) {
        guard !data.deudas.contains(where: { $0.id == deuda.id }) else { return }
        data.deudas.append(deuda)
        guardar()
    }
}

extension String {
    /// `nil` si el texto está vacío (para guardar notas opcionales).
    var nilSiVacio: String? { isEmpty ? nil : self }
}
