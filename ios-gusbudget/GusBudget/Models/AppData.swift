import Foundation

/// Ajustes de la app que no son del presupuesto.
struct Ajustes: Codable, Hashable {
    /// Fecha en que se firmó/instaló con el Apple ID gratuito.
    var ultimaFirma: Date?
    var recordatorioFirma: Bool
    /// Pedir Face ID o código al abrir.
    var bloqueoActivo: Bool

    init(ultimaFirma: Date? = nil, recordatorioFirma: Bool = false, bloqueoActivo: Bool = false) {
        self.ultimaFirma = ultimaFirma
        self.recordatorioFirma = recordatorioFirma
        self.bloqueoActivo = bloqueoActivo
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ultimaFirma = try c.decodeIfPresent(Date.self, forKey: .ultimaFirma)
        recordatorioFirma = try c.decodeIfPresent(Bool.self, forKey: .recordatorioFirma) ?? false
        bloqueoActivo = try c.decodeIfPresent(Bool.self, forKey: .bloqueoActivo) ?? false
    }
}

/// Todo lo que se guarda en el teléfono.
struct AppData: Codable {
    var version: Int
    /// Desde cuándo se registra: antes de esta fecha nada cuenta.
    var inicio: Date
    /// Dólar para las suscripciones en USD.
    var trm: Decimal
    var categorias: [Categoria]
    var fijos: [Fijo]
    var gastos: [Gasto]
    var agenda: [AgendaItem]
    var pagosFijos: [PagoFijo]
    var cajitas: [Cajita]
    var deudas: [Deuda]
    var ajustes: Ajustes

    static let versionActual = 1

    init(
        version: Int = AppData.versionActual,
        inicio: Date = Semilla.inicio,
        trm: Decimal = Semilla.trm,
        categorias: [Categoria] = Semilla.categorias,
        fijos: [Fijo] = Semilla.fijos,
        gastos: [Gasto] = [],
        agenda: [AgendaItem] = Semilla.agenda,
        pagosFijos: [PagoFijo] = [],
        cajitas: [Cajita] = Semilla.cajitas,
        deudas: [Deuda] = Semilla.deudas,
        ajustes: Ajustes = Ajustes()
    ) {
        self.version = version
        self.inicio = inicio
        self.trm = trm
        self.categorias = categorias
        self.fijos = fijos
        self.gastos = gastos
        self.agenda = agenda
        self.pagosFijos = pagosFijos
        self.cajitas = cajitas
        self.deudas = deudas
        self.ajustes = ajustes
    }

    /// Decodificación tolerante: un respaldo viejo al que le falte una clave debe abrirse igual.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        inicio = try c.decodeIfPresent(Date.self, forKey: .inicio) ?? Semilla.inicio
        trm = try c.decodeIfPresent(Decimal.self, forKey: .trm) ?? Semilla.trm
        categorias = try c.decodeIfPresent([Categoria].self, forKey: .categorias) ?? Semilla.categorias
        fijos = try c.decodeIfPresent([Fijo].self, forKey: .fijos) ?? Semilla.fijos
        gastos = try c.decodeIfPresent([Gasto].self, forKey: .gastos) ?? []
        agenda = try c.decodeIfPresent([AgendaItem].self, forKey: .agenda) ?? []
        pagosFijos = try c.decodeIfPresent([PagoFijo].self, forKey: .pagosFijos) ?? []
        cajitas = try c.decodeIfPresent([Cajita].self, forKey: .cajitas) ?? []
        deudas = try c.decodeIfPresent([Deuda].self, forKey: .deudas) ?? []
        ajustes = try c.decodeIfPresent(Ajustes.self, forKey: .ajustes) ?? Ajustes()
    }

    /// Datos vacíos pero con la configuración base (para "empezar de cero").
    static func limpio() -> AppData {
        AppData(gastos: [], agenda: [], pagosFijos: [], cajitas: [], deudas: Semilla.deudas)
    }
}
