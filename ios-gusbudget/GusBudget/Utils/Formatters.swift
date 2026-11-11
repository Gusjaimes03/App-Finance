import Foundation

enum Fmt {
    static let locale = Locale(identifier: "es_CO")

    private static let pesos: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = locale
        f.groupingSeparator = "."
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f
    }()

    /// "$ 1.234.567" (sin decimales, como la versión web).
    static func plata(_ valor: Decimal) -> String {
        let redondeado = valor.redondeado
        let texto = pesos.string(from: NSDecimalNumber(decimal: abs(redondeado))) ?? "0"
        return (redondeado < 0 ? "-$ " : "$ ") + texto
    }

    /// Igual que `plata` pero con signo explícito para los movimientos.
    static func conSigno(_ valor: Decimal, positivo: Bool) -> String {
        (positivo ? "+" : "−") + plata(abs(valor)).replacingOccurrences(of: "-", with: "")
    }

    /// Solo el número con separadores de miles, para los campos de texto.
    static func numero(_ valor: Decimal) -> String {
        pesos.string(from: NSDecimalNumber(decimal: valor.redondeado)) ?? "0"
    }

    static func porcentaje(_ valor: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.locale = locale
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: valor)) ?? "0 %"
    }

    /// Lee lo que escribe el usuario: quita puntos, comas y símbolos.
    static func leerPlata(_ texto: String) -> Decimal? {
        let limpio = texto.filter { $0.isNumber }
        guard !limpio.isEmpty else { return nil }
        return Decimal(string: limpio, locale: Locale(identifier: "en_US_POSIX"))
    }

    // MARK: Fechas

    private static func formato(_ plantilla: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = Calendar.app.timeZone
        f.setLocalizedDateFormatFromTemplate(plantilla)
        return f
    }

    private static let diaCorto = formato("EEE d MMM")
    private static let diaLargo = formato("EEEE d MMMM")
    private static let mesLargo = formato("MMMM yyyy")
    private static let mesCorto = formato("MMM")
    private static let diaMes = formato("d MMM")

    /// "mar 10 nov"
    static func fechaCorta(_ fecha: Date) -> String {
        diaCorto.string(from: fecha).replacingOccurrences(of: ".", with: "")
    }

    /// "10 nov"
    static func diaYMes(_ fecha: Date) -> String {
        diaMes.string(from: fecha).replacingOccurrences(of: ".", with: "")
    }

    /// "Hoy", "Ayer" o "martes 10 de noviembre"
    static func encabezadoDia(_ fecha: Date) -> String {
        if Calendar.app.isDateInToday(fecha) { return "Hoy" }
        if Calendar.app.isDateInYesterday(fecha) { return "Ayer" }
        if Calendar.app.isDateInTomorrow(fecha) { return "Mañana" }
        return diaLargo.string(from: fecha).mayusculaInicial
    }

    /// "noviembre 2026"
    static func mes(_ fecha: Date) -> String {
        mesLargo.string(from: fecha).mayusculaInicial
    }

    /// "nov"
    static func mesAbreviado(_ fecha: Date) -> String {
        mesCorto.string(from: fecha).replacingOccurrences(of: ".", with: "").mayusculaInicial
    }

    /// "2 p. m." para las franjas horarias.
    static func hora(_ hora: Int) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "h a"
        var componentes = DateComponents()
        componentes.year = 2026
        componentes.month = 1
        componentes.day = 1
        componentes.hour = ((hora % 24) + 24) % 24
        let fecha = Calendar.app.date(from: componentes) ?? Date()
        return f.string(from: fecha).lowercased()
    }
}

extension Decimal {
    var doble: Double { NSDecimalNumber(decimal: self).doubleValue }

    /// Pesos enteros: la app no maneja centavos.
    var redondeado: Decimal {
        var entrada = self
        var salida = Decimal()
        NSDecimalRound(&salida, &entrada, 0, .plain)
        return salida
    }

    /// Redondeo a la centena más cercana (valores típicos de hábitos).
    var redondeadoACien: Decimal {
        let cientos = (self / 100).redondeado
        return cientos * 100
    }
}

extension String {
    var mayusculaInicial: String {
        guard let primera = first else { return self }
        return primera.uppercased() + dropFirst()
    }

    /// Sin tildes ni diacríticos, en minúsculas (para agrupar notas).
    var sinTildes: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Fmt.locale)
    }
}
