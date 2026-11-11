import SwiftUI

struct InicioView: View {
    @EnvironmentObject private var store: FinanceStore

    @State private var solicitud: SolicitudValor?
    @State private var mostrarAjustes = false
    @State private var registro: RegistrarView.Tipo?

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
                VStack(spacing: 13) {
                    tarjetaHoy
                    botones
                    avisos
                    proximos
                    donaDelMes
                }
                .columna()
                .padding(.horizontal, 16)
                .padding(.bottom, 96)
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
                        Image(systemName: "gearshape")
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
            .sheet(item: $registro) { tipo in
                HojaRegistrar(tipo: tipo).environmentObject(store)
            }
        }
    }

    // MARK: Tarjeta principal

    private var tarjetaHoy: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(titulo)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(Fmt.encabezadoDia(Date()))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Text(Fmt.plata(abs(resultado.disponible)))
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(resultado.disponible < 0 ? Theme.rojo : Theme.sol)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(frase)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 7) {
                Mosaico(titulo: "Plata libre", valor: Fmt.plata(store.libre),
                        color: store.libre < 0 ? Theme.rojo : .white, sobreOscuro: true)
                Mosaico(titulo: "En cajitas", valor: Fmt.plata(store.enCajitas),
                        color: .white, sobreOscuro: true)
                Mosaico(titulo: "Esta semana", valor: Fmt.plata(store.gastadoEstaSemana),
                        color: .white, sobreOscuro: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.heroGradient)
        )
    }

    private var titulo: String {
        if store.libre < 0 { return "Estás en rojo" }
        return resultado.disponible < 0 ? "Hoy te pasaste" : "Hoy puedes gastar"
    }

    private var frase: String {
        let r = resultado
        if store.libre < 0 {
            return "Tu plata libre está en \(Fmt.plata(store.libre)). Revisa los pagos antes de seguir gastando."
        }
        if r.disponible < 0 {
            return "Te pasaste del límite de hoy. Mañana vuelve a empezar."
        }
        if r.mandaPresupuesto {
            return "Manda tu presupuesto: es lo que queda del día a día repartido en los días que faltan."
        }
        let dias = r.dias == 1 ? "1 día" : "\(r.dias) días"
        guard let proximo = r.proximoIngreso else {
            return "Tus \(Fmt.plata(r.libre)) libres repartidos en \(dias), hasta que acabe el mes."
        }
        return "\(Fmt.plata(r.libre)) libres − \(Fmt.plata(r.pagosAntes)) de pagos, en \(dias) hasta \(proximo.nombre)."
    }

    // MARK: Botones de registro

    private var botones: some View {
        HStack(spacing: 10) {
            Button {
                registro = .gasto
            } label: {
                Label("Registrar gasto", systemImage: "minus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.acento)

            Button {
                registro = .ingreso
            } label: {
                Label("Ingreso", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.vertical, 13)
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.bordered)
            .tint(Theme.verde)
        }
    }

    // MARK: Avisos

    @ViewBuilder
    private var avisos: some View {
        let lista = store.avisos()
        if !lista.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(lista.prefix(2).enumerated()), id: \.offset) { _, texto in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.ambar)
                            .padding(.top, 1)
                        Text(texto)
                            .font(.caption2)
                            .foregroundStyle(Theme.gris)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if lista.count > 2 {
                    Text("y \(lista.count - 2) aviso(s) más")
                        .font(.caption2)
                        .foregroundStyle(Theme.gris)
                }
            }
            .panel(padding: 12)
        }
    }

    // MARK: Pagos e ingresos cercanos

    @ViewBuilder
    private var proximos: some View {
        if !pagosCerca.isEmpty || !ingresosCerca.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if !pagosCerca.isEmpty {
                    TituloSeccion(texto: "Pagos de estos días")
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

            VStack(alignment: .leading, spacing: 12) {
                TituloSeccion(texto: "En qué se va tu plata", detalle: Fmt.mes(Date()))
                HStack(spacing: 12) {
                    Dona(tramos: tramos, total: total, grosor: 18, lado: 110)
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

/// El registro en 3 pasos, dentro de una hoja.
struct HojaRegistrar: View {
    let tipo: RegistrarView.Tipo

    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            ScrollView {
                RegistrarView(tipoInicial: tipo, alTerminar: { cerrar() })
                    .environmentObject(store)
                    .padding(16)
            }
            .background(Theme.fondo)
            .navigationTitle(tipo == .gasto ? "Registrar gasto" : "Ingreso extra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { cerrar() }
                }
            }
        }
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
