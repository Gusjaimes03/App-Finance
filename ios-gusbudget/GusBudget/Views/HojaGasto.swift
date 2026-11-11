import SwiftUI

/// Hoja para corregir o borrar un gasto.
struct HojaGasto: View {
    let gasto: Gasto

    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var cerrar
    @Environment(\.ofrecerDeshacer) private var ofrecerDeshacer

    @State private var texto = ""
    @State private var categoriaID = ""
    @State private var metodo: MetodoPago = .debito
    @State private var nota = ""
    @State private var fecha = Date()
    @State private var confirmarBorrado = false
    @State private var cargado = false

    private let columnas = [GridItem(.adaptive(minimum: 92), spacing: 10)]
    private var valorValido: Bool { Fmt.leerPlata(texto) != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Espacio.seccion) {
                    cabecera
                    seccionCategoria
                    seccionMetodo
                    seccionDetalles
                    acciones
                }
                .padding(.horizontal, Espacio.margen)
                .padding(.top, Espacio.xs)
                .padding(.bottom, Espacio.xl)
                .frame(maxWidth: 576)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.fondo.ignoresSafeArea())
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
                    .disabled(!valorValido)
                }
            }
            .confirmationDialog("¿Borrar este gasto?", isPresented: $confirmarBorrado, titleVisibility: .visible) {
                Button("Borrar gasto", role: .destructive) {
                    let tienda = store
                    tienda.borrarGasto(gasto)
                    ofrecerDeshacer { tienda.restaurarGasto(gasto) }
                    cerrar()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("\(Fmt.plata(gasto.monto)) en \(store.categoria(gasto.cat).nombre).")
            }
            .onAppear {
                guard !cargado else { return }
                cargado = true
                texto = Fmt.numero(gasto.monto)
                categoriaID = gasto.cat
                metodo = gasto.metodo
                nota = gasto.nota
                fecha = gasto.fecha
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Cabecera: categoría elegida y valor grande

    private var cabecera: some View {
        let categoria = store.categoria(categoriaID.isEmpty ? gasto.cat : categoriaID)
        return VStack(spacing: Espacio.s) {
            IconoCuadro(simbolo: categoria.simbolo, color: categoria.color, lado: 52)
            CampoPlata(texto: $texto, grande: true, alineacion: .center, etiqueta: "Valor del gasto")
                .padding(.horizontal, Espacio.m)
            Text("\(categoria.nombre) · \(Fmt.fechaCorta(fecha))")
                .font(.subheadline)
                .foregroundStyle(Theme.gris)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Espacio.l)
        .background(FondoTarjeta())
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: categoriaID)
    }

    // MARK: Categoría

    private var seccionCategoria: some View {
        VStack(alignment: .leading, spacing: Espacio.titulo) {
            EncabezadoSeccion(titulo: "Categoría")
            LazyVGrid(columns: columnas, spacing: 10) {
                ForEach(store.categoriasVisibles) { categoria in
                    MosaicoCategoria(simbolo: categoria.simbolo, color: categoria.color,
                                     nombre: categoria.nombre,
                                     seleccionado: categoria.id == categoriaID) {
                        categoriaID = categoria.id
                    }
                }
            }
        }
    }

    // MARK: Método de pago

    private var seccionMetodo: some View {
        VStack(alignment: .leading, spacing: Espacio.titulo) {
            EncabezadoSeccion(titulo: "Cómo pagaste")
            HStack(spacing: Espacio.xs) {
                ForEach(MetodoPago.allCases) { opcion in
                    OpcionMetodoGasto(metodo: opcion, elegido: metodo == opcion) {
                        Haptics.seleccion()
                        metodo = opcion
                    }
                }
            }
            if metodo == .credito {
                Text("Se suma a lo que debes en la \(MetodoPago.credito.titulo).")
                    .font(.footnote)
                    .foregroundStyle(Theme.gris)
                    .padding(.horizontal, Espacio.xxs)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Nota y fecha

    private var seccionDetalles: some View {
        VStack(alignment: .leading, spacing: Espacio.titulo) {
            EncabezadoSeccion(titulo: "Detalles")
            VStack(spacing: 0) {
                HStack(spacing: Espacio.s) {
                    Image(systemName: "text.alignleft")
                        .font(.body)
                        .foregroundStyle(Theme.gris)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    TextField("Nota", text: $nota)
                        .font(.body)
                        .submitLabel(.done)
                        .accessibilityLabel("Nota")
                }
                .padding(.horizontal, Espacio.m)
                .frame(minHeight: 52)

                SeparadorFila(sangria: 52)

                HStack(spacing: Espacio.s) {
                    Image(systemName: "calendar")
                        .font(.body)
                        .foregroundStyle(Theme.gris)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    DatePicker("Fecha", selection: $fecha, displayedComponents: .date)
                        .environment(\.locale, Fmt.locale)
                        .font(.body)
                        .foregroundStyle(Theme.texto)
                }
                .padding(.horizontal, Espacio.m)
                .frame(minHeight: 52)
            }
            .panel(padding: 0)
        }
    }

    // MARK: Guardar y borrar

    private var acciones: some View {
        VStack(spacing: Espacio.s) {
            Button("Guardar cambios") {
                guardar()
                cerrar()
            }
            .buttonStyle(.principal)
            .disabled(!valorValido)

            Button {
                Haptics.warning()
                confirmarBorrado = true
            } label: {
                Label("Borrar gasto", systemImage: "trash")
            }
            .buttonStyle(.secundario(Theme.rojo, anchoCompleto: true))
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
        let anterior = store.data.gastos.first(where: { $0.id == gasto.id }) ?? gasto
        let tienda = store
        tienda.actualizarGasto(copia)
        ofrecerDeshacer { tienda.actualizarGasto(anterior) }
    }
}

/// Opción de método de pago (Débito / Crédito) con ícono; marcada cuando está elegida.
private struct OpcionMetodoGasto: View {
    let metodo: MetodoPago
    let elegido: Bool
    var accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack(spacing: Espacio.xs) {
                Image(systemName: metodo.simbolo)
                    .font(.body.weight(.semibold))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(metodo.tituloCorto)
                        .font(.body.weight(elegido ? .semibold : .medium))
                    Text(metodo == .credito ? MetodoPago.credito.titulo : "o efectivo")
                        .font(.caption)
                        .foregroundStyle(elegido ? Theme.acento : Theme.gris)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if elegido {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(elegido ? Theme.acento : Theme.texto)
            .padding(.horizontal, Espacio.s)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: Radio.mosaico, style: .continuous)
                    .fill(elegido ? Theme.acentoSuave : Theme.superficie)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radio.mosaico, style: .continuous)
                    .strokeBorder(elegido ? Theme.acento : Theme.linea, lineWidth: elegido ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.presionable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metodo.titulo)
        .accessibilityAddTraits(elegido ? [.isButton, .isSelected] : .isButton)
    }
}
