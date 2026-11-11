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

struct HojaValorReal: View {
    let solicitud: SolicitudValor

    @Environment(\.dismiss) private var cerrar
    @State private var texto = ""
    @State private var fecha = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section(solicitud.pregunta) {
                    CampoPlata(texto: $texto, alineacion: .trailing)
                    DatePicker("Fecha", selection: $fecha, displayedComponents: .date)
                        .environment(\.locale, Fmt.locale)
                }
            }
            .navigationTitle(solicitud.titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        if let valor = Fmt.leerPlata(texto) {
                            solicitud.accion(valor, fecha)
                        }
                        cerrar()
                    }
                    .fontWeight(.semibold)
                    .disabled(Fmt.leerPlata(texto) == nil)
                }
            }
            .onAppear {
                texto = solicitud.montoSugerido > 0 ? Fmt.numero(solicitud.montoSugerido) : ""
                fecha = solicitud.fechaSugerida
            }
        }
        .presentationDetents([.height(260)])
    }
}

/// Fila de un pago o ingreso pendiente.
struct FilaObligacion: View {
    let obligacion: Obligacion
    var alHacer: () -> Void
    var alQuitar: (() -> Void)?

    var body: some View {
        HStack(spacing: 11) {
            IconoCuadro(
                simbolo: obligacion.simbolo,
                color: obligacion.tipo == .ingreso ? Theme.verde : Theme.acento,
                lado: 36
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(obligacion.nombre)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.texto)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if let etiqueta = obligacion.estado.etiqueta {
                        Text(etiqueta)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(obligacion.estado == .vencido
                                               ? Theme.rojo.opacity(0.15)
                                               : Theme.sol.opacity(0.25))
                            )
                            .foregroundStyle(obligacion.estado == .vencido ? Theme.rojo : Theme.ambar)
                    }
                }
                Text(obligacion.fechaMostrada)
                    .font(.caption2)
                    .foregroundStyle(Theme.gris)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 4) {
                Text(obligacion.monto > 0 ? Fmt.plata(obligacion.monto) : "Sin valor")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.texto)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Button(obligacion.tipo == .pago ? "Ya pagué" : "Ya me llegó", action: alHacer)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(obligacion.tipo == .pago ? Theme.acento : Theme.verde)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            if let alQuitar {
                Button(role: .destructive, action: alQuitar) {
                    Label("Quitar", systemImage: "trash")
                }
            }
        }
    }
}
