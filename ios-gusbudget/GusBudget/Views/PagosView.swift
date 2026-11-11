import SwiftUI

/// Pagos e ingresos esperados (sección 2.4).
struct PagosView: View {
    @EnvironmentObject private var store: FinanceStore

    @State private var solicitud: SolicitudValor?
    @State private var mostrarFormulario = false
    @State private var quitando: Obligacion?

    private var pendientes: [Obligacion] {
        // Lo que le deben a él se maneja en Balance, no aquí.
        store.obligaciones().filter { !$0.porCobrar }
    }

    struct GrupoObligaciones: Identifiable {
        let estado: EstadoObligacion
        let lista: [Obligacion]
        var id: String { estado.rawValue }
        var total: Decimal { lista.reduce(Decimal.zero) { $0 + $1.monto } }
    }

    private var grupos: [GrupoObligaciones] {
        let orden: [EstadoObligacion] = [.vencido, .pronto, .mes, .despues, .sinFecha]
        return orden.compactMap { estado -> GrupoObligaciones? in
            let lista = pendientes.filter { $0.estado == estado }
            return lista.isEmpty ? nil : GrupoObligaciones(estado: estado, lista: lista)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if pendientes.isEmpty {
                        Vacio(simbolo: "checkmark.seal", texto: "No tienes nada pendiente. Qué maravilla.")
                            .panel()
                    }

                    ForEach(grupos) { grupo in
                        VStack(alignment: .leading, spacing: 10) {
                            TituloSeccion(
                                texto: grupo.estado.titulo,
                                detalle: Fmt.plata(grupo.total)
                            )
                            ForEach(grupo.lista) { obligacion in
                                VStack(spacing: 6) {
                                    FilaObligacion(obligacion: obligacion) {
                                        solicitud = solicitudPara(obligacion, store: store)
                                    }
                                    if obligacion.agendaId != nil {
                                        HStack {
                                            Spacer()
                                            Button("Quitar") { quitando = obligacion }
                                                .font(.caption2)
                                                .foregroundStyle(Theme.rojo)
                                        }
                                    }
                                }
                            }
                        }
                        .panel()
                    }

                    botonAgregar
                    yaHechos
                }
                .columna()
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.fondo)
            .navigationTitle("Pagos")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $solicitud) { peticion in
                HojaValorReal(solicitud: peticion)
            }
            .sheet(isPresented: $mostrarFormulario) {
                HojaNuevoPago().environmentObject(store)
            }
            .confirmationDialog(
                "¿Quitar \(quitando?.nombre ?? "")?",
                isPresented: Binding(get: { quitando != nil }, set: { if !$0 { quitando = nil } }),
                titleVisibility: .visible
            ) {
                Button("Quitar", role: .destructive) {
                    if let quitando { store.quitar(quitando) }
                    quitando = nil
                }
                Button("Cancelar", role: .cancel) { quitando = nil }
            }
        }
    }

    private var botonAgregar: some View {
        Button {
            mostrarFormulario = true
        } label: {
            Label("Agregar un pago o un ingreso esperado", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.acento)
    }

    @ViewBuilder
    private var yaHechos: some View {
        let hechos = store.yaHechos()
        if !hechos.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                TituloSeccion(texto: "Ya hechos", detalle: "Los últimos \(hechos.count)")
                ForEach(hechos) { item in
                    HStack(spacing: 11) {
                        IconoCuadro(
                            simbolo: item.simbolo,
                            color: item.tipo == .ingreso ? Theme.verde : Theme.acento,
                            lado: 32
                        )
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.nombre)
                                .font(.subheadline)
                                .foregroundStyle(Theme.texto)
                                .lineLimit(1)
                            Text(Fmt.fechaCorta(item.hechoFecha ?? item.creado))
                                .font(.caption2)
                                .foregroundStyle(Theme.gris)
                        }
                        Spacer(minLength: 4)
                        Text(Fmt.plata(item.valorEfectivo))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(item.tipo == .ingreso ? Theme.verde : Theme.texto)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Button(item.extra || item.cobroId != nil ? "Borrar" : "Deshacer") {
                            if item.extra || item.cobroId != nil {
                                store.quitarAgenda(item)
                            } else {
                                store.deshacerAgenda(item)
                            }
                        }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
            }
            .panel()
        }
    }
}

/// Formulario "Agregar un pago o un ingreso esperado".
struct HojaNuevoPago: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var cerrar

    @State private var tipo: TipoAgenda = .pago
    @State private var nombre = ""
    @State private var texto = ""
    @State private var conFecha = true
    @State private var fecha = Date()

    var body: some View {
        NavigationStack {
            Form {
                Picker("Tipo", selection: $tipo) {
                    Text("Pago").tag(TipoAgenda.pago)
                    Text("Ingreso").tag(TipoAgenda.ingreso)
                }
                .pickerStyle(.segmented)

                Section("¿Qué es?") {
                    TextField(tipo == .pago ? "Arriendo, matrícula…" : "Sueldo, venta…", text: $nombre)
                }

                Section("Valor") {
                    CampoPlata(texto: $texto, alineacion: .trailing)
                }

                Section("¿Cuándo?") {
                    Toggle("Tiene fecha", isOn: $conFecha)
                    if conFecha {
                        DatePicker("Fecha", selection: $fecha, displayedComponents: .date)
                            .environment(\.locale, Fmt.locale)
                    }
                }
            }
            .navigationTitle(tipo == .pago ? "Nuevo pago" : "Nuevo ingreso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Agregar") {
                        guardar()
                        cerrar()
                    }
                    .fontWeight(.semibold)
                    .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty || Fmt.leerPlata(texto) == nil)
                }
            }
        }
    }

    private func guardar() {
        guard let monto = Fmt.leerPlata(texto) else { return }
        store.agregarAgenda(
            AgendaItem(
                tipo: tipo,
                nombre: nombre.trimmingCharacters(in: .whitespaces),
                monto: monto,
                fecha: conFecha ? fecha : nil,
                simbolo: tipo == .pago ? "calendar" : "arrow.down.circle.fill"
            )
        )
    }
}
