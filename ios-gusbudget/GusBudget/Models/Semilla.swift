import Foundation

/// Datos con los que arranca la app la primera vez (sección 6 de la especificación).
/// Todo se puede cambiar desde la propia app.
enum Semilla {
    static let inicio: Date = fecha(2026, 11, 6)
    static let trm: Decimal = 3235.59

    static func fecha(_ anio: Int, _ mes: Int, _ dia: Int) -> Date {
        var partes = DateComponents()
        partes.year = anio
        partes.month = mes
        partes.day = dia
        return Calendar.app.date(from: partes) ?? Date()
    }

    // MARK: Categorías

    static let categorias: [Categoria] = [
        Categoria(id: "comida", nombre: "Comida y mercado", mensual: 400_000, colorHex: "e8930c", simbolo: "fork.knife"),
        Categoria(id: "salidas", nombre: "Salidas y planes", mensual: 400_000, colorHex: "db3f8c", simbolo: "theatermasks.fill"),
        Categoria(id: "gasolina", nombre: "Gasolina", mensual: 400_000, colorHex: "e0443a", simbolo: "fuelpump.fill"),
        Categoria(id: "transporte", nombre: "Transporte (bus, taxi)", colorHex: "0f9cc4", simbolo: "bus.fill"),
        Categoria(id: "mascota", nombre: "Morita", colorHex: "9a6b3a", simbolo: "pawprint.fill"),
        Categoria(id: "hogar", nombre: "Casa y aseo", colorHex: "0f9e8c", simbolo: "house.fill"),
        Categoria(id: "salud", nombre: "Salud y farmacia", colorHex: "1f9d55", simbolo: "cross.case.fill"),
        Categoria(id: "estudio", nombre: "Estudio y trabajo", colorHex: "3a6ee8", simbolo: "book.fill"),
        Categoria(id: "ropa", nombre: "Ropa y cuidado personal", colorHex: "8456e0", simbolo: "tshirt.fill"),
        Categoria(id: "regalos", nombre: "Regalos", colorHex: "f06a1f", simbolo: "gift.fill"),
        Categoria(id: "familia", nombre: "Familia", colorHex: "6f9a12", simbolo: "person.2.fill"),
        Categoria(id: "otros", nombre: "Otros", colorHex: "7b869e", simbolo: "ellipsis.circle.fill")
    ]

    // MARK: Gastos fijos y suscripciones

    static let fijos: [Fijo] = [
        Fijo(id: "arriendo", nombre: "Arriendo", monto: 1_000_000, dia: 28, simbolo: "house.fill"),
        Fijo(id: "servicios", nombre: "Servicios públicos", monto: 200_000, dia: nil, simbolo: "bolt.fill"),
        Fijo(
            id: "guamacard",
            nombre: "Guamacard (pago total)",
            monto: nil,
            dia: 25,
            cuenta: false,
            deudaId: "guamacard",
            nota: "Paga las compras ya registradas, por eso no suma al presupuesto",
            simbolo: "creditcard.fill"
        ),
        Fijo(id: "ahorro_carro", nombre: "Ahorro mantenimiento carro", monto: 150_000, dia: nil, simbolo: "car.fill"),
        Fijo(
            id: "cuota_carro",
            nombre: "Cuota carro (padrastro)",
            monto: 2_000_000,
            dia: nil,
            deudaId: "carro",
            desde: "2027-04",
            simbolo: "car.fill"
        ),
        Fijo(id: "s_claude", nombre: "Claude Max", usd: 100, dia: nil, grupo: "suscripcion", simbolo: "sparkles"),
        Fijo(
            id: "s_yavoy",
            nombre: "YaVoy (servidor, base de datos y APIs)",
            usd: 50,
            dia: nil,
            grupo: "suscripcion",
            nota: "Costo del negocio",
            simbolo: "server.rack"
        ),
        Fijo(id: "s_apple", nombre: "Apple Music e iCloud", monto: nil, dia: nil, grupo: "suscripcion", simbolo: "music.note")
    ]

    // MARK: Ingresos esperados y cobros

    static var agenda: [AgendaItem] {
        [
            AgendaItem(
                tipo: .ingreso,
                nombre: "Comfacasanare (quincena del 15)",
                monto: 1_400_000,
                fecha: fecha(2026, 11, 20),
                fechaTexto: "~16-20 nov",
                nota: "Pagan hasta 5 días hábiles después del 15. No pagan en diciembre ni enero.",
                simbolo: "building.2.fill"
            ),
            AgendaItem(
                tipo: .ingreso,
                nombre: "CLI",
                monto: 824_600,
                fecha: fecha(2026, 11, 12),
                fechaTexto: "~del 10 en adelante",
                simbolo: "person.fill.checkmark"
            ),
            AgendaItem(
                tipo: .ingreso,
                nombre: "Unitrópico",
                monto: 3_800_000,
                fecha: fecha(2026, 11, 30),
                fechaTexto: "~30 nov",
                nota: "Pagan el 28; si cae fin de semana, el siguiente día hábil.",
                simbolo: "graduationcap.fill"
            ),
            AgendaItem(
                tipo: .ingreso,
                nombre: "Comfacasanare (quincena del 30)",
                monto: 1_400_000,
                fecha: fecha(2026, 12, 4),
                fechaTexto: "~1-5 dic",
                nota: "No pagan en diciembre ni enero.",
                simbolo: "building.2.fill"
            ),
            // Lo que le deben: ingresos pendientes sin fecha.
            AgendaItem(
                tipo: .ingreso,
                nombre: "Mamá",
                monto: 500_000,
                porCobrar: true,
                persona: "Mamá",
                montoOriginal: 1_000_000,
                simbolo: "heart.fill"
            ),
            AgendaItem(
                tipo: .ingreso,
                nombre: "Papá",
                monto: 600_000,
                porCobrar: true,
                persona: "Papá",
                montoOriginal: 600_000,
                simbolo: "heart.fill"
            ),
            AgendaItem(
                tipo: .ingreso,
                nombre: "2 estudiantes de CLI",
                monto: 235_600,
                porCobrar: true,
                persona: "Estudiantes CLI",
                montoOriginal: 235_600,
                simbolo: "person.2.fill"
            )
        ]
    }

    // MARK: Cajitas de ahorro

    static var cajitas: [Cajita] {
        [
            Cajita(nombre: "Arriendo de noviembre", meta: 1_000_000, para: "arriendo", colorHex: "2c56e0", orden: 0),
            Cajita(nombre: "Colchón enero y febrero", meta: 4_400_000, colorHex: "0f766e", orden: 1, nota: "Estimada: esos meses no hay Comfacasanare"),
            Cajita(nombre: "SOAT del carro (marzo)", meta: 1_121_400, colorHex: "c2410c", orden: 2)
        ]
    }

    // MARK: Deudas

    static let deudas: [Deuda] = [
        Deuda(
            id: "carro",
            nombre: "Carro (padrastro)",
            saldo: 28_000_000,
            original: 30_000_000,
            valorBien: 30_000_000,
            cuota: 2_000_000,
            nota: "Cuotas de $2.000.000 desde abril de 2027",
            orden: 0
        ),
        Deuda(id: "monet", nombre: "Monet", saldo: 442_000, original: 442_000, orden: 1),
        Deuda(id: "guamacard", nombre: "Guamacard", saldo: 400_000, original: 400_000, nota: "Tarjeta de crédito", orden: 2)
    ]

    /// Fuentes que se ofrecen al registrar un ingreso extra.
    static let fuentesExtra = ["Clase particular", "Venta", "Regalo", "Reembolso", "Trabajo extra", "Otro"]
}

// MARK: - Datos de ejemplo (solo para capturas y pruebas visuales)

extension Semilla {
    /// Un mes con movimientos, pagos hechos y cajitas con plata,
    /// para ver cómo se ven las pantallas llenas.
    static func ejemplo() -> AppData {
        let hoy = Date()
        let mes = hoy.inicioDeMes

        func dia(_ numero: Int) -> Date {
            mes.sumandoDias(max(0, numero - 1))
        }

        func gasto(_ monto: Decimal, _ cat: String, _ nota: String, _ numero: Int, _ hora: String, _ metodo: MetodoPago = .debito) -> Gasto {
            Gasto(monto: monto, cat: cat, metodo: metodo, nota: nota, fecha: dia(numero), hora: hora, creado: dia(numero))
        }

        var datos = AppData(
            inicio: mes,
            gastos: [
                gasto(12_000, "comida", "Onces", 2, "15:10"),
                gasto(9_000, "comida", "Onces", 4, "14:40"),
                gasto(9_500, "comida", "Onces", 6, "15:30"),
                gasto(38_000, "comida", "Mercado", 3, "11:20"),
                gasto(120_000, "comida", "Mercado del mes", 7, "10:05"),
                gasto(60_000, "gasolina", "Tanqueada", 2, "07:40"),
                gasto(60_000, "gasolina", "Tanqueada", 8, "08:15"),
                gasto(45_000, "salidas", "Cine con Dani", 5, "20:10"),
                gasto(85_000, "salidas", "Almuerzo del domingo", 9, "13:20"),
                gasto(18_000, "transporte", "Taxi al centro", 4, "18:50"),
                gasto(32_000, "mascota", "Comida de Morita", 6, "17:00"),
                gasto(54_000, "hogar", "Aseo", 7, "16:30"),
                gasto(70_000, "salud", "Farmacia", 8, "09:30", .credito),
                gasto(25_000, "comida", "Almuerzo", 9, "12:40"),
                gasto(15_000, "comida", "Onces", 9, "15:05")
            ],
            cajitas: cajitas,
            deudas: deudas
        )

        datos.agenda = [
            AgendaItem(
                tipo: .ingreso, nombre: "Comfacasanare (quincena del 15)", monto: 1_400_000,
                fecha: dia(20), fechaTexto: "~16-20 nov", simbolo: "building.2.fill"
            ),
            AgendaItem(
                tipo: .ingreso, nombre: "Unitrópico", monto: 3_800_000,
                fecha: dia(30), fechaTexto: "~30 nov", simbolo: "graduationcap.fill"
            ),
            AgendaItem(
                tipo: .ingreso, nombre: "CLI", monto: 824_600, fecha: dia(10),
                hecho: true, hechoMonto: 824_600, hechoFecha: dia(10),
                simbolo: "person.fill.checkmark"
            ),
            AgendaItem(
                tipo: .ingreso, nombre: "Comfacasanare (quincena del 30)", monto: 1_400_000,
                fecha: dia(2), hecho: true, hechoMonto: 1_142_255, hechoFecha: dia(2),
                simbolo: "building.2.fill"
            ),
            AgendaItem(
                tipo: .pago, nombre: "Matrícula del semestre", monto: 189_000,
                fecha: dia(14), simbolo: "graduationcap.fill"
            ),
            AgendaItem(
                tipo: .ingreso, nombre: "Clase particular", monto: 120_000, fecha: dia(6),
                hecho: true, hechoMonto: 120_000, hechoFecha: dia(6),
                extra: true, fuente: "Clase particular", simbolo: "plus.circle.fill"
            ),
            AgendaItem(
                tipo: .ingreso, nombre: "Mamá", monto: 500_000, porCobrar: true,
                persona: "Mamá", montoOriginal: 1_000_000, simbolo: "heart.fill"
            ),
            AgendaItem(
                tipo: .ingreso, nombre: "2 estudiantes de CLI", monto: 235_600, porCobrar: true,
                persona: "Estudiantes CLI", montoOriginal: 235_600, simbolo: "person.2.fill"
            )
        ]

        datos.pagosFijos = [
            PagoFijo(fijoId: "servicios", periodo: mes.clavePeriodo, monto: 150_000,
                     fecha: dia(5), presupuesto: 200_000)
        ]

        datos.cajitas = [
            Cajita(nombre: "Arriendo de noviembre", meta: 1_000_000, guardado: 650_000,
                   para: "arriendo", colorHex: "2c56e0", orden: 0),
            Cajita(nombre: "Colchón enero y febrero", meta: 4_400_000, guardado: 150_000,
                   colorHex: "0f766e", orden: 1, nota: "Esos meses no hay Comfacasanare"),
            Cajita(nombre: "SOAT del carro (marzo)", meta: 1_121_400, guardado: 200_000,
                   colorHex: "c2410c", orden: 2)
        ]

        return datos
    }
}
