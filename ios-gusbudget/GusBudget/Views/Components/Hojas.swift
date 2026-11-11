import SwiftUI

/// Petición de "¿Cuánto pagaste de verdad?" con fecha.
struct SolicitudValor: Identifiable {
    let id = UUID()
    var titulo: String
    var pregunta: String
    var montoSugerido: Decimal
    var fechaSugerida: Date = Date()
    var accion: (Decimal, Date) -> Void
}

// MARK: - Hoja de valor real

/// Hoja "¿Cuánto pagaste de verdad?": cifra grande centrada, fecha y botón principal.
struct HojaValorReal: View {
    let solicitud: SolicitudValor

    @Environment(\.dismiss) private var cerrar
    @State private var texto = ""
    @State private var fecha = Date()

    private var valor: Decimal? { Fmt.leerPlata(texto) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Espacio.l) {
                    VStack(spacing: Espacio.xs) {
                        Text(solicitud.pregunta)
                            .font(.headline)
                            .foregroundStyle(Theme.gris)
                            .multilineTextAlignment(.center)
                        CampoPlata(texto: $texto, grande: true, alineacion: .center,
                                   etiqueta: solicitud.pregunta, enfocarAlAparecer: true)
                    }
                    .padding(.top, Espacio.xs)

                    DatePicker("Fecha", selection: $fecha, displayedComponents: .date)
                        .environment(\.locale, Fmt.locale)
                        .font(.body)
                        .padding(.horizontal, Espacio.m)
                        .frame(minHeight: 52)
                        .background(
                            RoundedRectangle(cornerRadius: Radio.campo, style: .continuous)
                                .fill(Theme.hundido)
                        )

                    Button("Guardar") { guardar() }
                        .buttonStyle(.principal)
                        .disabled(valor == nil)
                }
                .padding(.horizontal, Espacio.margen)
                .padding(.bottom, Espacio.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.elevada.ignoresSafeArea())
            .navigationTitle(solicitud.titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardar() }
                        .fontWeight(.semibold)
                        .disabled(valor == nil)
                }
            }
            .onAppear {
                texto = solicitud.montoSugerido > 0 ? Fmt.numero(solicitud.montoSugerido) : ""
                fecha = solicitud.fechaSugerida
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func guardar() {
        if let valor { solicitud.accion(valor, fecha) }
        cerrar()
    }
}

// MARK: - Fila de obligación

/// Fila de un pago o ingreso pendiente, estilo Recordatorios: check circular a la izquierda,
/// nombre y fecha al centro, valor a la derecha.
/// Dentro de una `List` funcionan los deslizamientos; en cualquier contenedor funciona el menú contextual.
struct FilaObligacion: View {
    let obligacion: Obligacion
    var alHacer: () -> Void
    var alQuitar: (() -> Void)?
    /// Abre la ficha para editar (tocar el nombre o el valor también la abre).
    var alEditar: (() -> Void)?

    private var esPago: Bool { obligacion.tipo == .pago }
    private var textoAccion: String { esPago ? "Ya pagué" : "Ya me llegó" }

    private var tonoEstado: Tono {
        obligacion.estado == .vencido ? .negativo : .aviso
    }

    var body: some View {
        HStack(spacing: Espacio.s) {
            BotonCheck(color: esPago ? Theme.acento : Theme.verde,
                       etiqueta: "\(textoAccion): \(obligacion.nombre)",
                       accion: alHacer)
                .padding(.leading, -6)

            HStack(spacing: Espacio.s) {
                VStack(alignment: .leading, spacing: 3) {
                    // El estado ("Pronto", "Vencido") va junto al nombre para que la fecha tenga toda la línea.
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(obligacion.nombre)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.texto)
                            .lineLimit(2)
                        if let etiqueta = obligacion.estado.etiqueta {
                            Insignia(texto: etiqueta, tono: tonoEstado)
                                .fixedSize()
                                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + 4 }
                        }
                    }
                    Text(obligacion.fechaMostrada)
                        .font(.subheadline)
                        .foregroundStyle(Theme.gris)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Group {
                    if obligacion.monto > 0 {
                        CifraPlata(valor: obligacion.monto, estilo: .normal,
                                   signo: esPago ? .ninguno : .entrada)
                    } else {
                        Text("Sin valor")
                            .font(.subheadline)
                            .foregroundStyle(Theme.grisClaro)
                    }
                }
                .layoutPriority(1)
            }
            .contentShape(Rectangle())
            .onTapGesture { alEditar?() }
        }
        .padding(.vertical, Espacio.xs)
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: alHacer) {
                Label(textoAccion, systemImage: "checkmark.circle")
            }
            if let alEditar {
                Button(action: alEditar) {
                    Label("Editar", systemImage: "pencil")
                }
            }
            if let alQuitar {
                Button(role: .destructive, action: alQuitar) {
                    Label("Borrar", systemImage: "trash")
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: alHacer) {
                Label(textoAccion, systemImage: "checkmark")
            }
            .tint(esPago ? Theme.acento : Theme.verde)
        }
        .swipeActions(edge: .trailing) {
            if let alQuitar {
                Button(role: .destructive, action: alQuitar) {
                    Label("Borrar", systemImage: "trash")
                }
            }
            if let alEditar {
                Button(action: alEditar) {
                    Label("Editar", systemImage: "pencil")
                }
                .tint(Theme.acento)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: textoAccion, alHacer)
        .accessibilityAction(named: "Editar") { alEditar?() }
    }
}

// MARK: - Hoja de registro

/// Hoja que envuelve `RegistrarView` para registrar desde el botón flotante.
/// Se cierra sola cuando se guarda un gasto o un ingreso.
struct HojaRegistrar: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var cerrar

    @State private var gastosAlAbrir = 0
    @State private var agendaAlAbrir = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                RegistrarView()
                    .padding(.horizontal, Espacio.m)
                    .padding(.top, Espacio.xs)
                    .padding(.bottom, Espacio.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.fondo.ignoresSafeArea())
            .navigationTitle("Registrar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { cerrar() }
                }
            }
        }
        .environment(\.alTerminarRegistro, { cerrar() })
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            gastosAlAbrir = store.data.gastos.count
            agendaAlAbrir = store.data.agenda.count
        }
        .onChange(of: store.data.gastos.count) { nuevo in
            if nuevo > gastosAlAbrir { cerrar() }
        }
        .onChange(of: store.data.agenda.count) { nuevo in
            if nuevo > agendaAlAbrir { cerrar() }
        }
    }
}
