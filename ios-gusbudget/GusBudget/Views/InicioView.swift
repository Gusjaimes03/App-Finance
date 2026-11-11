import SwiftUI

struct InicioView: View {
    @EnvironmentObject private var store: FinanceStore
    @State private var solicitud: SolicitudValor?
    @State private var mostrarAjustes = false

    private var resultado: ResultadoHoy { store.hoyPuedesGastar() }
    private var pendientes: [Obligacion] { store.obligaciones() }

    private var pagosCerca: [Obligacion] {
        pendientes.filter { $0.tipo == .pago && ($0.estado == .vencido || $0.estado == .pronto) }
    }

    private var ingresosCerca: [Obligacion] {
        pendientes.filter { $0.tipo == .ingreso && ($0.estado == .vencido || $0.estado == .pronto) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    tarjetaHoy
                    avisos
                    RegistrarView()
                    proximos
                    donaDelMes
                }
                .columna()
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.fondo)
            .navigationTitle("Mi plata")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        mostrarAjustes = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Ajustes")
                }
            }
            .sheet(isPresented: $mostrarAjustes) {
                AjustesView().environmentObject(store)
            }
            .sheet(item: $solicitud) { peticion in
                HojaValorReal(solicitud: peticion)
            }
        }
    }

    // MARK: Tarjeta principal

    private var tarjetaHoy: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(resultado.disponible < 0 ? "Hoy te pasaste" : "Hoy puedes gastar")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))

            Text(Fmt.plata(abs(resultado.disponible)))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(resultado.disponible < 0 ? Theme.rojo : Theme.sol)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(frase)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Mosaico(titulo: "Plata libre", valor: Fmt.plata(store.libre),
                        color: store.libre < 0 ? Theme.rojo : .white, sobreOscuro: true)
                Mosaico(titulo: "En cajitas", valor: Fmt.plata(store.enCajitas),
                        color: .white, sobreOscuro: true)
                Mosaico(titulo: "Esta semana", valor: Fmt.plata(store.gastadoEstaSemana),
                        color: .white, sobreOscuro: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.heroGradient)
        )
    }

    private var frase: String {
        let r = resultado
        if r.disponible < 0 {
            return "Te pasaste del límite de hoy. Mañana vuelve a empezar."
        }
        if r.mandaPresupuesto {
            return "Manda tu presupuesto del mes: es lo que queda del día a día repartido en los días que faltan."
        }
        let destino = r.proximoIngreso.map { "hasta que llegue \($0.nombre)" } ?? "hasta que acabe el mes"
        let dias = r.dias == 1 ? "1 día" : "\(r.dias) días"
        return "Tienes \(Fmt.plata(r.libre)) libres, apartas \(Fmt.plata(r.pagosAntes)) para pagos y lo repartes en \(dias), \(destino)."
    }

    // MARK: Avisos

    @ViewBuilder
    private var avisos: some View {
        let lista = store.avisos()
        if !lista.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(lista.enumerated()), id: \.offset) { _, texto in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.ambar)
                        Text(texto)
                            .font(.caption)
                            .foregroundStyle(Theme.texto)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .panel(padding: 13)
        }
    }

    // MARK: Pagos e ingresos cercanos

    @ViewBuilder
    private var proximos: some View {
        if !pagosCerca.isEmpty || !ingresosCerca.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if !pagosCerca.isEmpty {
                    TituloSeccion(texto: "Pagos de los próximos 7 días")
                    ForEach(pagosCerca) { obligacion in
                        FilaObligacion(obligacion: obligacion, alHacer: {
                            solicitud = solicitudPara(obligacion, store: store)
                        })
                    }
                }

                if !ingresosCerca.isEmpty {
                    if !pagosCerca.isEmpty { Divider() }
                    TituloSeccion(texto: "Te debe llegar")
                    ForEach(ingresosCerca) { obligacion in
                        FilaObligacion(obligacion: obligacion, alHacer: {
                            solicitud = solicitudPara(obligacion, store: store)
                        })
                    }
                }
            }
            .panel()
        }
    }

    // MARK: Dona del mes

    @ViewBuilder
    private var donaDelMes: some View {
        let totales = store.totalesPorCategoria(mes: Date())
        if !totales.isEmpty {
            let total = totales.reduce(Decimal.zero) { $0 + $1.total }
            let tramos = tramosDona(totales)

            VStack(alignment: .leading, spacing: 14) {
                TituloSeccion(texto: "En qué se va tu plata", detalle: Fmt.mes(Date()))
                HStack(spacing: 14) {
                    Dona(tramos: tramos, total: total, lado: 124)
                    LeyendaDona(tramos: tramos, total: total)
                }
            }
            .panel()
        }
    }

    /// Las 4 categorías principales y el resto agrupado en "Otras".
    private func tramosDona(_ totales: [TotalCategoria]) -> [TramoDona] {
        var lista = totales.prefix(4).map {
            TramoDona(id: $0.categoria.id, valor: $0.total.doble, color: $0.categoria.color, nombre: $0.categoria.nombre)
        }
        let otras = totales.dropFirst(4).reduce(Decimal.zero) { $0 + $1.total }
        if otras > 0 {
            lista.append(TramoDona(id: "otras", valor: otras.doble, color: Theme.gris, nombre: "Otras"))
        }
        return lista
    }
}

/// Construye la hoja de "¿cuánto fue de verdad?" para una obligación.
func solicitudPara(_ obligacion: Obligacion, store: FinanceStore) -> SolicitudValor {
    SolicitudValor(
        titulo: obligacion.nombre,
        pregunta: obligacion.tipo == .pago ? "¿Cuánto pagaste de verdad?" : "¿Cuánto te llegó?",
        montoSugerido: obligacion.monto,
        fechaSugerida: Date()
    ) { monto, fecha in
        store.registrar(obligacion, monto: monto, fecha: fecha)
    }
}
