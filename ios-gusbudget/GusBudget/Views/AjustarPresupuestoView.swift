import SwiftUI

/// "Ajustar mi presupuesto y categorías" (sección 2.3).
struct AjustarPresupuestoView: View {
    @EnvironmentObject private var store: FinanceStore

    @State private var nuevaCategoria = ""
    @State private var nuevaCategoriaMonto = ""
    @State private var nuevoFijo = ""
    @State private var nuevoFijoMonto = ""
    @State private var nuevoFijoDia = ""
    @State private var nuevaSus = ""
    @State private var nuevaSusMonto = ""
    @State private var nuevaSusEnDolares = false
    @State private var nuevaSusDia = ""

    var body: some View {
        Form {
            Section("Dólar (TRM)") {
                HStack {
                    Text("1 USD")
                    Spacer()
                    TextField("3.235", text: bindingTRM)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                }
                DatePicker(
                    "Registro desde",
                    selection: Binding(get: { store.data.inicio }, set: { store.actualizarInicio($0) }),
                    displayedComponents: .date
                )
                .environment(\.locale, Fmt.locale)
            }

            Section("Presupuesto mensual por categoría") {
                ForEach(store.categoriasVisibles) { categoria in
                    HStack(spacing: 10) {
                        IconoCuadro(simbolo: categoria.simbolo, color: categoria.color, lado: 28)
                        Text(categoria.nombre)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        TextField("0", text: bindingMensual(categoria))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 110)
                    }
                    .swipeActions(edge: .trailing) {
                        if categoria.esDelUsuario {
                            Button(role: .destructive) {
                                store.ocultarCategoria(categoria)
                            } label: {
                                Label("Quitar", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section("Agregar categoría") {
                TextField("Nombre", text: $nuevaCategoria)
                HStack {
                    Text("Monto mensual")
                    Spacer()
                    CampoPlata(texto: $nuevaCategoriaMonto, alineacion: .trailing)
                        .frame(maxWidth: 140)
                }
                Button("Agregar categoría") {
                    store.agregarCategoria(
                        nombre: nuevaCategoria.trimmingCharacters(in: .whitespaces),
                        mensual: Fmt.leerPlata(nuevaCategoriaMonto) ?? 0
                    )
                    nuevaCategoria = ""
                    nuevaCategoriaMonto = ""
                }
                .disabled(nuevaCategoria.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Section("Gastos fijos y suscripciones") {
                ForEach(store.data.fijos) { fijo in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            IconoCuadro(simbolo: fijo.simbolo, color: Theme.acento, lado: 26)
                            Text(fijo.nombre)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            TextField(fijo.usd != nil ? "USD" : "0", text: bindingFijo(fijo))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 100)
                        }
                        HStack {
                            Text("Día de pago")
                                .font(.caption)
                                .foregroundStyle(Theme.gris)
                            Spacer()
                            TextField("—", text: bindingDia(fijo))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 60)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        if fijo.esDelUsuario {
                            Button(role: .destructive) {
                                store.quitarFijo(fijo)
                            } label: {
                                Label("Quitar", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section("Agregar un gasto fijo") {
                TextField("Nombre", text: $nuevoFijo)
                HStack {
                    Text("Valor")
                    Spacer()
                    CampoPlata(texto: $nuevoFijoMonto, alineacion: .trailing)
                        .frame(maxWidth: 140)
                }
                HStack {
                    Text("Día")
                    Spacer()
                    TextField("—", text: $nuevoFijoDia)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 60)
                }
                Button("Agregar gasto fijo") {
                    store.agregarFijo(
                        nombre: nuevoFijo.trimmingCharacters(in: .whitespaces),
                        monto: Fmt.leerPlata(nuevoFijoMonto),
                        usd: nil,
                        dia: Int(nuevoFijoDia),
                        suscripcion: false
                    )
                    nuevoFijo = ""
                    nuevoFijoMonto = ""
                    nuevoFijoDia = ""
                }
                .disabled(nuevoFijo.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Section("Agregar una suscripción") {
                TextField("Nombre", text: $nuevaSus)
                Toggle("Cobra en dólares", isOn: $nuevaSusEnDolares)
                HStack {
                    Text(nuevaSusEnDolares ? "Valor en USD" : "Valor")
                    Spacer()
                    TextField("0", text: $nuevaSusMonto)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }
                HStack {
                    Text("Día de cobro")
                    Spacer()
                    TextField("—", text: $nuevaSusDia)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 60)
                }
                Button("Agregar suscripción") {
                    let valor = Fmt.leerPlata(nuevaSusMonto)
                    store.agregarFijo(
                        nombre: nuevaSus.trimmingCharacters(in: .whitespaces),
                        monto: nuevaSusEnDolares ? nil : valor,
                        usd: nuevaSusEnDolares ? valor : nil,
                        dia: Int(nuevaSusDia),
                        suscripcion: true
                    )
                    nuevaSus = ""
                    nuevaSusMonto = ""
                    nuevaSusDia = ""
                }
                .disabled(nuevaSus.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Ajustar")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Enlaces con el store

    private var bindingTRM: Binding<String> {
        Binding(
            get: { Fmt.numero(store.data.trm) },
            set: { nuevo in
                if let valor = Fmt.leerPlata(nuevo) { store.actualizarTRM(valor) }
            }
        )
    }

    private func bindingMensual(_ categoria: Categoria) -> Binding<String> {
        Binding(
            get: { categoria.mensual > 0 ? Fmt.numero(categoria.mensual) : "" },
            set: { nuevo in
                var copia = categoria
                copia.mensual = Fmt.leerPlata(nuevo) ?? 0
                store.actualizarCategoria(copia)
            }
        )
    }

    private func bindingFijo(_ fijo: Fijo) -> Binding<String> {
        Binding(
            get: {
                if let usd = fijo.usd { return Fmt.numero(usd) }
                if let monto = fijo.monto { return Fmt.numero(monto) }
                return ""
            },
            set: { nuevo in
                var copia = fijo
                let valor = Fmt.leerPlata(nuevo)
                if fijo.usd != nil {
                    copia.usd = valor
                } else {
                    copia.monto = valor
                }
                store.actualizarFijo(copia)
            }
        )
    }

    private func bindingDia(_ fijo: Fijo) -> Binding<String> {
        Binding(
            get: { fijo.dia.map(String.init) ?? "" },
            set: { nuevo in
                var copia = fijo
                if let dia = Int(nuevo.filter { $0.isNumber }), (1...31).contains(dia) {
                    copia.dia = dia
                } else {
                    copia.dia = nil
                }
                store.actualizarFijo(copia)
            }
        )
    }
}
