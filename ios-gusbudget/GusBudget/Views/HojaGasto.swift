import SwiftUI

/// Hoja para corregir o borrar un gasto.
struct HojaGasto: View {
    let gasto: Gasto

    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var cerrar

    @State private var texto = ""
    @State private var categoriaID = ""
    @State private var metodo: MetodoPago = .debito
    @State private var nota = ""
    @State private var fecha = Date()
    @State private var confirmarBorrado = false

    private let columnas = [GridItem(.adaptive(minimum: 94), spacing: 9)]

    var body: some View {
        NavigationStack {
            Form {
                Section("Valor") {
                    CampoPlata(texto: $texto, alineacion: .trailing)
                }

                Section("Categoría") {
                    LazyVGrid(columns: columnas, spacing: 9) {
                        ForEach(store.categoriasVisibles) { categoria in
                            Button {
                                categoriaID = categoria.id
                                Haptics.tap()
                            } label: {
                                VStack(spacing: 5) {
                                    IconoCuadro(
                                        simbolo: categoria.simbolo,
                                        color: categoria.color,
                                        lado: 30,
                                        relleno: categoria.id == categoriaID
                                    )
                                    Text(categoria.nombre)
                                        .font(.system(size: 10))
                                        .foregroundStyle(Theme.texto)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 72)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Cómo pagaste") {
                    Picker("Método", selection: $metodo) {
                        ForEach(MetodoPago.allCases) { opcion in
                            Text(opcion.titulo).tag(opcion)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Detalles") {
                    TextField("Nota", text: $nota)
                    DatePicker("Fecha", selection: $fecha, displayedComponents: .date)
                        .environment(\.locale, Fmt.locale)
                }

                Section {
                    Button(role: .destructive) {
                        if confirmarBorrado {
                            store.borrarGasto(gasto)
                            cerrar()
                        } else {
                            confirmarBorrado = true
                            Haptics.warning()
                        }
                    } label: {
                        Text(confirmarBorrado ? "Toca otra vez para borrar" : "Borrar gasto")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Corregir gasto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        guardar()
                        cerrar()
                    }
                    .fontWeight(.semibold)
                    .disabled(Fmt.leerPlata(texto) == nil)
                }
            }
            .onAppear {
                texto = Fmt.numero(gasto.monto)
                categoriaID = gasto.cat
                metodo = gasto.metodo
                nota = gasto.nota
                fecha = gasto.fecha
            }
        }
    }

    private func guardar() {
        guard let monto = Fmt.leerPlata(texto) else { return }
        var copia = gasto
        copia.monto = monto
        copia.cat = categoriaID
        copia.metodo = metodo
        copia.nota = nota
        copia.fecha = fecha.inicioDeDia
        store.actualizarGasto(copia)
    }
}
