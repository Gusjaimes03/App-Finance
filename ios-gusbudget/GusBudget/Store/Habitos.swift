import Foundation

/// Un grupo de gastos que se repiten: "onces", "gasolina", "almuerzo"… (regla 4.7).
struct Habito: Identifiable {
    let id: String
    let palabra: String
    let categoriaID: String
    let categoriaNombre: String
    let veces: Int
    /// Mediana redondeada a $100.
    let valorTipico: Decimal
    let metodo: MetodoPago
    let horas: [Double]

    var horaDesde: Int? { horas.min().map { Int($0.rounded(.down)) } }
    var horaHasta: Int? { horas.max().map { Int($0.rounded(.up)) } }

    var titulo: String { palabra.mayusculaInicial }

    /// "Onces · 3 veces · Comida y mercado · entre las 2 p. m. y las 4 p. m. · $9.000"
    var descripcion: String {
        var partes = ["\(veces) veces", categoriaNombre]
        if let desde = horaDesde, let hasta = horaHasta {
            partes.append(desde == hasta
                          ? "a las \(Fmt.hora(desde))"
                          : "entre las \(Fmt.hora(desde)) y las \(Fmt.hora(hasta))")
        }
        partes.append(Fmt.plata(valorTipico))
        return partes.joined(separator: " · ")
    }
}

extension FinanceStore {
    /// Palabras que no sirven para agrupar.
    static let palabrasVacias: Set<String> = [
        "de", "del", "la", "el", "los", "las", "con", "y", "en", "para", "por",
        "un", "una", "hoy", "ayer", "mi", "semana", "pasada", "al", "a"
    ]

    /// Primera palabra útil de la nota, sin tildes y en minúsculas.
    static func palabraClave(_ nota: String) -> String? {
        for palabra in nota.sinTildes.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            let limpia = String(palabra).lowercased()
            if limpia.count > 2 && !palabrasVacias.contains(limpia) { return limpia }
        }
        return nil
    }

    /// Agrupa los gastos por categoría + palabra clave.
    func habitos() -> [Habito] {
        var grupos: [String: [Gasto]] = [:]
        for gasto in data.gastos {
            guard let palabra = Self.palabraClave(gasto.nota) else { continue }
            grupos["\(gasto.cat)|\(palabra)", default: []].append(gasto)
        }

        return grupos.compactMap { clave, gastos -> Habito? in
            guard gastos.count >= 2 else { return nil }
            let partes = clave.split(separator: "|")
            guard partes.count == 2 else { return nil }

            let montos = gastos.map(\.monto).sorted()
            let mediana = montos[montos.count / 2]

            var cuentaMetodo: [MetodoPago: Int] = [:]
            for gasto in gastos { cuentaMetodo[gasto.metodo, default: 0] += 1 }
            let metodo = cuentaMetodo.max { $0.value < $1.value }?.key ?? .debito

            return Habito(
                id: clave,
                palabra: String(partes[1]),
                categoriaID: String(partes[0]),
                categoriaNombre: categoria(String(partes[0])).nombre,
                veces: gastos.count,
                valorTipico: mediana.redondeadoACien,
                metodo: metodo,
                horas: gastos.compactMap(\.horaDecimal)
            )
        }
        .sorted { $0.veces > $1.veces }
    }

    /// Distancia circular entre dos horas en un reloj de 24 h.
    static func distanciaHoraria(_ a: Double, _ b: Double) -> Double {
        let diferencia = abs(a - b).truncatingRemainder(dividingBy: 24)
        return min(diferencia, 24 - diferencia)
    }

    /// "A esta hora sueles comprar": máximo 3 hábitos cerca de la hora actual.
    func sugerencias(ahora: Date = Date()) -> (lista: [Habito], porHora: Bool) {
        let partes = Calendar.app.dateComponents([.hour, .minute], from: ahora)
        let hora = Double(partes.hour ?? 0) + Double(partes.minute ?? 0) / 60

        let cercanos = habitos()
            .map { habito -> (Habito, Int) in
                let coincidencias = habito.horas.filter { Self.distanciaHoraria($0, hora) <= 1.5 }.count
                return (habito, coincidencias)
            }
            .filter { $0.1 >= 2 }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map(\.0)

        if !cercanos.isEmpty { return (cercanos, true) }
        return (Array(habitos().prefix(3)), false)
    }
}
