import Foundation
import SwiftUI

// MARK: - Enumeraciones

enum MetodoPago: String, Codable, CaseIterable, Identifiable, Hashable {
    case debito
    case credito

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .debito: return "Débito o efectivo"
        case .credito: return "Guamacard"
        }
    }

    var tituloCorto: String {
        switch self {
        case .debito: return "Débito"
        case .credito: return "Crédito"
        }
    }

    var simbolo: String {
        switch self {
        case .debito: return "banknote"
        case .credito: return "creditcard.fill"
        }
    }
}

enum TipoAgenda: String, Codable, CaseIterable, Identifiable, Hashable {
    case pago
    case ingreso

    var id: String { rawValue }

    var titulo: String { self == .pago ? "Pago" : "Ingreso" }
    var accion: String { self == .pago ? "Ya pagué" : "Ya me llegó" }
}

/// En qué momento cae una obligación respecto a hoy.
enum EstadoObligacion: String {
    case vencido, pronto, mes, despues, sinFecha

    var titulo: String {
        switch self {
        case .vencido: return "Vencidos o pendientes"
        case .pronto: return "Próximos 7 días"
        case .mes: return "Resto del mes"
        case .despues: return "Más adelante"
        case .sinFecha: return "Sin fecha"
        }
    }

    var etiqueta: String? {
        switch self {
        case .vencido: return "Vencido"
        case .pronto: return "Pronto"
        default: return nil
        }
    }

    var orden: Int {
        switch self {
        case .vencido: return 0
        case .pronto: return 1
        case .mes: return 2
        case .despues: return 3
        case .sinFecha: return 4
        }
    }
}

// MARK: - Configuración

struct Categoria: Codable, Identifiable, Hashable {
    var id: String
    var nombre: String
    /// Presupuesto mensual del día a día. 0 = sin presupuesto.
    var mensual: Decimal
    var colorHex: String
    var simbolo: String
    var oculta: Bool

    init(
        id: String,
        nombre: String,
        mensual: Decimal = 0,
        colorHex: String = "7b869e",
        simbolo: String = "ellipsis.circle.fill",
        oculta: Bool = false
    ) {
        self.id = id
        self.nombre = nombre
        self.mensual = mensual
        self.colorHex = colorHex
        self.simbolo = simbolo
        self.oculta = oculta
    }

    var color: Color { Color(hex: colorHex) }
    /// Las que creó el usuario se pueden quitar.
    var esDelUsuario: Bool { id.hasPrefix("c_") }
}

struct Fijo: Codable, Identifiable, Hashable {
    var id: String
    var nombre: String
    /// Valor mensual en pesos. `nil` = variable (se pregunta al pagar).
    var monto: Decimal?
    /// Si existe, el valor en pesos se calcula con la TRM.
    var usd: Decimal?
    /// Día del mes en que vence.
    var dia: Int?
    /// Aparece en Pagos y en los próximos vencimientos.
    var aviso: Bool
    /// Suma al presupuesto del mes. `false` para el pago de la tarjeta.
    var cuenta: Bool
    /// "suscripcion" agrupa en su propia sección.
    var grupo: String?
    /// Al pagarlo baja el saldo de esta deuda.
    var deudaId: String?
    var desde: String?
    var hasta: String?
    var nota: String?
    var simbolo: String

    init(
        id: String,
        nombre: String,
        monto: Decimal? = nil,
        usd: Decimal? = nil,
        dia: Int? = nil,
        aviso: Bool = true,
        cuenta: Bool = true,
        grupo: String? = nil,
        deudaId: String? = nil,
        desde: String? = nil,
        hasta: String? = nil,
        nota: String? = nil,
        simbolo: String = "calendar"
    ) {
        self.id = id
        self.nombre = nombre
        self.monto = monto
        self.usd = usd
        self.dia = dia
        self.aviso = aviso
        self.cuenta = cuenta
        self.grupo = grupo
        self.deudaId = deudaId
        self.desde = desde
        self.hasta = hasta
        self.nota = nota
        self.simbolo = simbolo
    }

    var esSuscripcion: Bool { grupo == "suscripcion" }
    var esDelUsuario: Bool { id.hasPrefix("f_") || id.hasPrefix("s_") }

    /// Valor en pesos: si está en dólares se multiplica por la TRM.
    func montoEnPesos(trm: Decimal) -> Decimal? {
        if let usd { return (usd * trm).redondeado }
        return monto
    }

    /// ¿La regla aplica en este periodo "AAAA-MM"?
    func aplicaEn(periodo: String) -> Bool {
        if let desde, periodo < desde { return false }
        if let hasta, periodo > hasta { return false }
        return true
    }
}

// MARK: - Movimientos

struct Gasto: Codable, Identifiable, Hashable {
    var id: UUID
    var monto: Decimal
    var cat: String
    var metodo: MetodoPago
    var nota: String
    var fecha: Date
    /// "HH:MM" solo cuando se anotó el mismo día (sirve para los hábitos).
    var hora: String?
    var creado: Date

    init(
        id: UUID = UUID(),
        monto: Decimal,
        cat: String,
        metodo: MetodoPago = .debito,
        nota: String = "",
        fecha: Date = Date(),
        hora: String? = nil,
        creado: Date = Date()
    ) {
        self.id = id
        self.monto = monto
        self.cat = cat
        self.metodo = metodo
        self.nota = nota
        self.fecha = fecha.inicioDeDia
        self.hora = hora
        self.creado = creado
    }

    /// Hora en formato decimal (14.5 = 2:30 p. m.) si se conoce.
    var horaDecimal: Double? {
        if let hora {
            let partes = hora.split(separator: ":")
            if partes.count == 2, let h = Double(partes[0]), let m = Double(partes[1]) {
                return h + m / 60
            }
        }
        // Si se anotó el mismo día, la hora de creación sirve.
        if creado.mismoDia(que: fecha) {
            let partes = Calendar.app.dateComponents([.hour, .minute], from: creado)
            return Double(partes.hour ?? 0) + Double(partes.minute ?? 0) / 60
        }
        return nil
    }
}

struct AgendaItem: Codable, Identifiable, Hashable {
    var id: UUID
    var tipo: TipoAgenda
    var nombre: String
    var monto: Decimal
    var fecha: Date?
    /// Texto cuando la fecha es aproximada ("~16-20 nov").
    var fechaTexto: String?
    var nota: String?
    var hecho: Bool
    var hechoMonto: Decimal?
    var hechoFecha: Date?
    /// Alguien le debe: ingreso pendiente que no es sueldo.
    var porCobrar: Bool
    var persona: String?
    var montoOriginal: Decimal?
    /// Abono parcial de un cobro.
    var cobroId: UUID?
    var deudaId: String?
    var abono: Bool
    /// Ingreso extra (clase particular, venta…).
    var extra: Bool
    var fuente: String?
    /// Plata prestada que entra (no es sueldo).
    var prestamo: Bool
    /// Ajuste para cuadrar con el banco.
    var ajuste: Bool
    var creado: Date
    var simbolo: String

    init(
        id: UUID = UUID(),
        tipo: TipoAgenda,
        nombre: String,
        monto: Decimal,
        fecha: Date? = nil,
        fechaTexto: String? = nil,
        nota: String? = nil,
        hecho: Bool = false,
        hechoMonto: Decimal? = nil,
        hechoFecha: Date? = nil,
        porCobrar: Bool = false,
        persona: String? = nil,
        montoOriginal: Decimal? = nil,
        cobroId: UUID? = nil,
        deudaId: String? = nil,
        abono: Bool = false,
        extra: Bool = false,
        fuente: String? = nil,
        prestamo: Bool = false,
        ajuste: Bool = false,
        creado: Date = Date(),
        simbolo: String = "calendar"
    ) {
        self.id = id
        self.tipo = tipo
        self.nombre = nombre
        self.monto = monto
        self.fecha = fecha?.inicioDeDia
        self.fechaTexto = fechaTexto
        self.nota = nota
        self.hecho = hecho
        self.hechoMonto = hechoMonto
        self.hechoFecha = hechoFecha?.inicioDeDia
        self.porCobrar = porCobrar
        self.persona = persona
        self.montoOriginal = montoOriginal
        self.cobroId = cobroId
        self.deudaId = deudaId
        self.abono = abono
        self.extra = extra
        self.fuente = fuente
        self.prestamo = prestamo
        self.ajuste = ajuste
        self.creado = creado
        self.simbolo = simbolo
    }

    /// Valor real si ya se hizo; si no, el esperado.
    var valorEfectivo: Decimal { hecho ? (hechoMonto ?? monto) : monto }

    /// Mes al que pertenece: el de la fecha real si ya se hizo.
    var mesContable: Date? { (hecho ? (hechoFecha ?? fecha) : fecha) }

    /// Ingreso que cuenta como sueldo en el presupuesto del mes.
    var esSueldo: Bool {
        tipo == .ingreso && !porCobrar && !extra && cobroId == nil && !prestamo && !ajuste
    }
}

struct PagoFijo: Codable, Identifiable, Hashable {
    /// "<fijoId>_<AAAA-MM>"
    var id: String
    var fijoId: String
    var periodo: String
    /// Lo que se pagó de verdad.
    var monto: Decimal
    var fecha: Date
    /// Lo que estaba presupuestado en ese momento.
    var presupuesto: Decimal
    var creado: Date

    init(fijoId: String, periodo: String, monto: Decimal, fecha: Date, presupuesto: Decimal, creado: Date = Date()) {
        self.id = "\(fijoId)_\(periodo)"
        self.fijoId = fijoId
        self.periodo = periodo
        self.monto = monto
        self.fecha = fecha.inicioDeDia
        self.presupuesto = presupuesto
        self.creado = creado
    }

    /// Positivo si pagó menos de lo presupuestado.
    var ahorro: Decimal { presupuesto - monto }
}

// MARK: - Balance

struct Cajita: Codable, Identifiable, Hashable {
    var id: UUID
    var nombre: String
    var meta: Decimal
    var guardado: Decimal
    /// Id del fijo o del pago que cubre esta cajita.
    var para: String?
    var colorHex: String
    var orden: Int
    var nota: String

    init(
        id: UUID = UUID(),
        nombre: String,
        meta: Decimal,
        guardado: Decimal = 0,
        para: String? = nil,
        colorHex: String = "2c56e0",
        orden: Int = 0,
        nota: String = ""
    ) {
        self.id = id
        self.nombre = nombre
        self.meta = meta
        self.guardado = guardado
        self.para = para
        self.colorHex = colorHex
        self.orden = orden
        self.nota = nota
    }

    var color: Color { Color(hex: colorHex) }
    var falta: Decimal { max(0, meta - guardado) }
    var avance: Double { meta > 0 ? min(1, guardado.doble / meta.doble) : 1 }
    var completa: Bool { guardado >= meta && meta > 0 }
}

struct Deuda: Codable, Identifiable, Hashable {
    var id: String
    var nombre: String
    var saldo: Decimal
    var original: Decimal
    /// Valor del bien que se está pagando a cuotas (carro, moto…).
    var valorBien: Decimal?
    var cuota: Decimal?
    var nota: String
    var orden: Int

    init(
        id: String,
        nombre: String,
        saldo: Decimal,
        original: Decimal,
        valorBien: Decimal? = nil,
        cuota: Decimal? = nil,
        nota: String = "",
        orden: Int = 0
    ) {
        self.id = id
        self.nombre = nombre
        self.saldo = saldo
        self.original = original
        self.valorBien = valorBien
        self.cuota = cuota
        self.nota = nota
        self.orden = orden
    }

    var pagado: Decimal { max(0, original - saldo) }
    var avance: Double { original > 0 ? min(1, pagado.doble / original.doble) : 0 }
    var pagada: Bool { saldo <= 0 }
}

// MARK: - Obligación (se calcula, no se guarda)

struct Obligacion: Identifiable, Hashable {
    var id: String
    var tipo: TipoAgenda
    var nombre: String
    var monto: Decimal
    var fecha: Date?
    var fechaTexto: String?
    var nota: String?
    var simbolo: String
    var estado: EstadoObligacion
    /// Viene de un gasto fijo del presupuesto.
    var fijoId: String?
    var periodo: String?
    var agendaId: UUID?
    var deudaId: String?
    var porCobrar: Bool
    var persona: String?

    var esFijo: Bool { fijoId != nil }

    var fechaMostrada: String {
        if let texto = fechaTexto?.fechaSinTilde, !texto.isEmpty { return texto }
        if let fecha { return Fmt.diaYMes(fecha) }
        return "Sin fecha"
    }
}

extension String {
    /// Las fechas aproximadas venían con "~" adelante ("~16-20 nov"); se muestran sin él.
    var fechaSinTilde: String {
        var texto = trimmingCharacters(in: .whitespacesAndNewlines)
        while texto.hasPrefix("~") { texto.removeFirst() }
        texto = texto.trimmingCharacters(in: .whitespaces)
        guard let primera = texto.first else { return texto }
        return primera.uppercased() + texto.dropFirst()
    }
}
