import Foundation

/// Acciones que se disparan desde las listas de pendientes.
extension FinanceStore {
    /// "Ya pagué" / "Ya me llegó" sobre cualquier obligación.
    func registrar(_ obligacion: Obligacion, monto: Decimal, fecha: Date) {
        if let fijoId = obligacion.fijoId,
           let periodo = obligacion.periodo,
           let fijo = fijo(fijoId) {
            pagarFijo(fijo, periodo: periodo, monto: monto, fecha: fecha)
            return
        }
        guard let agendaId = obligacion.agendaId,
              let item = data.agenda.first(where: { $0.id == agendaId }) else { return }

        if item.porCobrar {
            registrarCobro(item, monto: monto, fecha: fecha)
        } else {
            marcarHecho(item, monto: monto, fecha: fecha)
        }
    }

    /// Quitar una obligación de la lista (solo las de la agenda).
    func quitar(_ obligacion: Obligacion) {
        guard let agendaId = obligacion.agendaId,
              let item = data.agenda.first(where: { $0.id == agendaId }) else { return }
        quitarAgenda(item)
    }

    /// Últimos movimientos ya hechos, para la sección "Ya hechos".
    func yaHechos(limite: Int = 30) -> [AgendaItem] {
        data.agenda
            .filter { $0.hecho }
            .sorted { ($0.hechoFecha ?? $0.creado) > ($1.hechoFecha ?? $1.creado) }
            .prefix(limite)
            .map { $0 }
    }

    /// Ingreso extra registrado desde la pantalla de inicio.
    func agregarIngresoExtra(monto: Decimal, fuente: String, nota: String, fecha: Date) {
        let item = AgendaItem(
            tipo: .ingreso,
            nombre: nota.isEmpty ? fuente : nota,
            monto: monto.redondeado,
            fecha: fecha,
            nota: nota.isEmpty ? nil : nota,
            hecho: true,
            hechoMonto: monto.redondeado,
            hechoFecha: fecha,
            extra: true,
            fuente: fuente,
            simbolo: "plus.circle.fill"
        )
        data.agenda.append(item)
        guardar()
        avisar("Ingreso guardado")
    }
}
