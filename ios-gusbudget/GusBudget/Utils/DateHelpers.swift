import Foundation

extension Calendar {
    /// Calendario fijo en la zona horaria de Colombia, como la versión web.
    static let app: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "es_CO")
        calendar.timeZone = TimeZone(identifier: "America/Bogota") ?? .current
        return calendar
    }()
}

extension Date {
    var inicioDeDia: Date { Calendar.app.startOfDay(for: self) }

    var inicioDeMes: Date {
        let partes = Calendar.app.dateComponents([.year, .month], from: self)
        return Calendar.app.date(from: partes) ?? self
    }

    var finDeMes: Date {
        let siguiente = inicioDeMes.sumandoMeses(1)
        return Calendar.app.date(byAdding: .day, value: -1, to: siguiente) ?? self
    }

    var diasDelMes: Int {
        Calendar.app.range(of: .day, in: .month, for: self)?.count ?? 30
    }

    var diaDelMes: Int { Calendar.app.component(.day, from: self) }

    func sumandoDias(_ valor: Int) -> Date {
        Calendar.app.date(byAdding: .day, value: valor, to: self) ?? self
    }

    func sumandoMeses(_ valor: Int) -> Date {
        Calendar.app.date(byAdding: .month, value: valor, to: self) ?? self
    }

    func mismoMes(que otra: Date) -> Bool {
        Calendar.app.isDate(self, equalTo: otra, toGranularity: .month)
    }

    func mismoDia(que otra: Date) -> Bool {
        Calendar.app.isDate(self, equalTo: otra, toGranularity: .day)
    }

    /// Días enteros entre dos fechas (positivo si `self` es posterior).
    func dias(desde otra: Date) -> Int {
        Calendar.app.dateComponents([.day], from: otra.inicioDeDia, to: inicioDeDia).day ?? 0
    }

    /// Clave "AAAA-MM" del mes.
    var clavePeriodo: String {
        let partes = Calendar.app.dateComponents([.year, .month], from: self)
        return String(format: "%04d-%02d", partes.year ?? 2026, partes.month ?? 1)
    }

    /// Fecha del primer día del periodo "AAAA-MM".
    static func desdePeriodo(_ periodo: String) -> Date? {
        let partes = periodo.split(separator: "-")
        guard partes.count == 2, let anio = Int(partes[0]), let mes = Int(partes[1]) else { return nil }
        var componentes = DateComponents()
        componentes.year = anio
        componentes.month = mes
        componentes.day = 1
        return Calendar.app.date(from: componentes)
    }

    /// Hora local "HH:MM".
    var horaTexto: String {
        let partes = Calendar.app.dateComponents([.hour, .minute], from: self)
        return String(format: "%02d:%02d", partes.hour ?? 0, partes.minute ?? 0)
    }
}
