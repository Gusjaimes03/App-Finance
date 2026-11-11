import SwiftUI
import UIKit

/// "Ajustar mi presupuesto y categorías" (sección 2.3).
///
/// Form nativo agrupado: topes por categoría (editables en la fila), gastos fijos y
/// suscripciones (cada uno abre su ficha), y la configuración del mes (TRM y fecha de inicio).
/// Lo nuevo se agrega desde una hoja pequeña, no con formularios siempre abiertos.
struct AjustarPresupuestoView: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.ofrecerDeshacer) private var ofrecerDeshacer

    @State private var hoja: HojaAgregar?
    @State private var fijoPorBorrar: Fijo?

    private enum HojaAgregar: String, Identifiable {
        case categoria, fijo, suscripcion
        var id: String { rawValue }
    }

    private var fijosNormales: [Fijo] { store.data.fijos.filter { !$0.esSuscripcion } }
    private var suscripciones: [Fijo] { store.data.fijos.filter { $0.esSuscripcion } }

    private var tituloBorrado: String {
        if let fijo = fijoPorBorrar { return "¿Borrar \(fijo.nombre)?" }
        return "¿Borrar?"
    }

    var body: some View {
        Form {
            Section {
                ForEach(store.categoriasVisibles) { categoria in
                    filaCategoria(categoria)
                        .listRowBackground(Theme.superficie)
                }
                botonAgregar("Nueva categoría") { hoja = .categoria }
                    .listRowBackground(Theme.superficie)
            } header: {
                Text("Topes del día a día")
            } footer: {
                Text("Cuánto planeas gastar al mes en cada categoría. Déjalo en 0 si no le quieres poner tope. Desliza a la izquierda para borrar una categoría que creaste.")
            }

            Section {
                ForEach(fijosNormales) { fijo in
                    filaFijo(fijo)
                        .listRowBackground(Theme.superficie)
                }
                botonAgregar("Nuevo gasto fijo") { hoja = .fijo }
                    .listRowBackground(Theme.superficie)
            } header: {
                Text("Gastos fijos")
            } footer: {
                Text("Arriendo, servicios, cuotas: lo que pagas cada mes. Toca uno para cambiar su valor o su día.")
            }

            Section {
                ForEach(suscripciones) { fijo in
                    filaFijo(fijo)
                        .listRowBackground(Theme.superficie)
                }
                botonAgregar("Nueva suscripción") { hoja = .suscripcion }
                    .listRowBackground(Theme.superficie)
            } header: {
                Text("Suscripciones")
            }

            Section {
                HStack(spacing: Espacio.xs) {
                    Text("Dólar (TRM)")
                    Spacer(minLength: Espacio.xs)
                    Text("$")
                        .foregroundStyle(Theme.gris)
                        .accessibilityHidden(true)
                    TextField("3.235", text: bindingTRM)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .monospacedDigit()
                        .frame(maxWidth: 120)
                        .accessibilityLabel("Valor del dólar en pesos")
                }
                .listRowBackground(Theme.superficie)

                DatePicker(
                    "Registro desde",
                    selection: Binding(get: { store.data.inicio }, set: { store.actualizarInicio($0) }),
                    displayedComponents: .date
                )
                .environment(\.locale, Fmt.locale)
                .listRowBackground(Theme.superficie)
            } header: {
                Text("Configuración")
            } footer: {
                Text("Con la TRM se pasan a pesos las suscripciones que cobran en dólares. «Registro desde» es la fecha desde la que llevas tus cuentas en la app.")
            }
        }
        .scrollContentBackground(.hidden)
        .fondoPantalla()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Ajustar presupuesto")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Listo") { ocultarTeclado() }
                    .fontWeight(.semibold)
            }
        }
        .sheet(item: $hoja) { tipo in
            switch tipo {
            case .categoria:
                HojaNuevaCategoria().environmentObject(store)
            case .fijo:
                HojaNuevoFijo(suscripcion: false).environmentObject(store)
            case .suscripcion:
                HojaNuevoFijo(suscripcion: true).environmentObject(store)
            }
        }
        .confirmationDialog(
            tituloBorrado,
            isPresented: Binding(
                get: { fijoPorBorrar != nil },
                set: { if !$0 { fijoPorBorrar = nil } }
            ),
            titleVisibility: .visible,
            presenting: fijoPorBorrar
        ) { fijo in
            Button("Borrar", role: .destructive) {
                store.quitarFijo(fijo)
                fijoPorBorrar = nil
            }
            Button("Cancelar", role: .cancel) { fijoPorBorrar = nil }
        } message: { _ in
            Text("Deja de contar en tu presupuesto. Esto no se puede deshacer.")
        }
    }

    // MARK: Filas

    private func filaCategoria(_ categoria: Categoria) -> some View {
        HStack(spacing: Espacio.s) {
            IconoCuadro(simbolo: categoria.simbolo, color: categoria.color, lado: 30)
            Text(categoria.nombre)
                .foregroundStyle(Theme.texto)
                .lineLimit(1)
            Spacer(minLength: Espacio.xs)
            Text("$")
                .foregroundStyle(Theme.gris)
                .accessibilityHidden(true)
            TextField("0", text: bindingMensual(categoria))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.system(.body, design: .rounded).weight(.medium))
                .monospacedDigit()
                .frame(minWidth: 70, maxWidth: 130)
                .accessibilityLabel("Tope mensual de \(categoria.nombre)")
        }
        .frame(minHeight: 44)
        .swipeActions(edge: .trailing) {
            if categoria.esDelUsuario {
                Button(role: .destructive) {
                    borrarCategoria(categoria)
                } label: {
                    Label("Borrar", systemImage: "trash")
                }
            }
        }
    }

    private func filaFijo(_ fijo: Fijo) -> some View {
        NavigationLink {
            EditarFijoView(fijoID: fijo.id).environmentObject(store)
        } label: {
            HStack(spacing: Espacio.s) {
                IconoCuadro(simbolo: fijo.simbolo, color: fijo.esSuscripcion ? Theme.acento : Theme.gris, lado: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(fijo.nombre)
                        .foregroundStyle(Theme.texto)
                        .lineLimit(1)
                    Text(detalleFijo(fijo))
                        .font(.subheadline)
                        .foregroundStyle(Theme.gris)
                        .lineLimit(1)
                }
                Spacer(minLength: Espacio.xs)
                if let valor = store.montoFijo(fijo) {
                    CifraPlata(valor: valor, estilo: .normal, signo: .ninguno)
                } else {
                    Text("Variable")
                        .foregroundStyle(Theme.gris)
                }
            }
            .frame(minHeight: 44)
            .accessibilityElement(children: .combine)
        }
        .swipeActions(edge: .trailing) {
            if fijo.esDelUsuario {
                Button {
                    Haptics.warning()
                    fijoPorBorrar = fijo
                } label: {
                    Label("Borrar", systemImage: "trash")
                }
                .tint(Theme.rojo)
            }
        }
    }

    private func detalleFijo(_ fijo: Fijo) -> String {
        var partes: [String] = []
        if let usd = fijo.usd { partes.append("USD \(Fmt.numero(usd))") }
        partes.append(fijo.dia.map { "Día \($0)" } ?? "Sin día de pago")
        return partes.joined(separator: " · ")
    }

    private func botonAgregar(_ titulo: String, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            Label(titulo, systemImage: "plus.circle.fill")
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.acento)
                .frame(minHeight: 44)
        }
    }

    // MARK: Acciones

    private func borrarCategoria(_ categoria: Categoria) {
        let tienda = store
        tienda.ocultarCategoria(categoria)
        ofrecerDeshacer("Categoría borrada") {
            var copia = categoria
            copia.oculta = false
            tienda.actualizarCategoria(copia)
        }
    }

    private func ocultarTeclado() {
        _ = UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
}

// MARK: - Ficha de un gasto fijo

/// Ficha nativa de un gasto fijo o suscripción: valor, día de pago y borrar.
private struct EditarFijoView: View {
    let fijoID: String

    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var cerrar
    @State private var confirmarBorrado = false

    private var fijo: Fijo? { store.data.fijos.first { $0.id == fijoID } }

    var body: some View {
        Group {
            if let fijo {
                formulario(fijo)
            } else {
                Color.clear
            }
        }
        .fondoPantalla()
        .navigationTitle(fijo?.nombre ?? "Gasto fijo")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formulario(_ fijo: Fijo) -> some View {
        Form {
            Section {
                if fijo.usd != nil {
                    HStack(spacing: Espacio.xs) {
                        Text("Valor en dólares")
                        Spacer(minLength: Espacio.xs)
                        Text("USD")
                            .foregroundStyle(Theme.gris)
                            .accessibilityHidden(true)
                        campoValor(fijo, marcador: "0")
                            .accessibilityLabel("Valor en dólares de \(fijo.nombre)")
                    }
                    .listRowBackground(Theme.superficie)

                    if let pesos = store.montoFijo(fijo) {
                        HStack {
                            Text("En pesos")
                            Spacer()
                            CifraPlata(valor: pesos, estilo: .normal, signo: .ninguno, color: Theme.gris)
                        }
                        .accessibilityElement(children: .combine)
                        .listRowBackground(Theme.superficie)
                    }
                } else {
                    HStack(spacing: Espacio.xs) {
                        Text("Valor mensual")
                        Spacer(minLength: Espacio.xs)
                        Text("$")
                            .foregroundStyle(Theme.gris)
                            .accessibilityHidden(true)
                        campoValor(fijo, marcador: "Variable")
                            .accessibilityLabel("Valor mensual de \(fijo.nombre)")
                    }
                    .listRowBackground(Theme.superficie)
                }

                Picker(fijo.esSuscripcion ? "Día de cobro" : "Día de pago", selection: bindingDia(fijo)) {
                    Text("Sin día").tag(Int?.none)
                    ForEach(1...31, id: \.self) { dia in
                        Text("\(dia)").tag(Int?.some(dia))
                    }
                }
                .listRowBackground(Theme.superficie)
            } footer: {
                Text(fijo.usd != nil
                     ? "Se pasa a pesos con la TRM de \(Fmt.plata(store.data.trm))."
                     : "Si cambia cada mes, déjalo vacío: te preguntamos cuánto pagaste cuando marques «Ya pagué».")
            }

            if fijo.esDelUsuario {
                Section {
                    Button(role: .destructive) {
                        Haptics.warning()
                        confirmarBorrado = true
                    } label: {
                        Text(fijo.esSuscripcion ? "Borrar suscripción" : "Borrar gasto fijo")
                            .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(Theme.superficie)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .confirmationDialog("¿Borrar \(fijo.nombre)?", isPresented: $confirmarBorrado, titleVisibility: .visible) {
            Button("Borrar", role: .destructive) {
                store.quitarFijo(fijo)
                cerrar()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Deja de contar en tu presupuesto. Esto no se puede deshacer.")
        }
    }

    private func campoValor(_ fijo: Fijo, marcador: String) -> some View {
        TextField(marcador, text: bindingFijo(fijo))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .font(.system(.body, design: .rounded).weight(.medium))
            .monospacedDigit()
            .frame(maxWidth: 140)
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

    private func bindingDia(_ fijo: Fijo) -> Binding<Int?> {
        Binding(
            get: { fijo.dia },
            set: { nuevo in
                var copia = fijo
                if let nuevo, (1...31).contains(nuevo) {
                    copia.dia = nuevo
                } else {
                    copia.dia = nil
                }
                store.actualizarFijo(copia)
            }
        )
    }
}

// MARK: - Hoja: nueva categoría

private struct HojaNuevaCategoria: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var cerrar

    @State private var nombre = ""
    @State private var monto = ""
    @FocusState private var nombreEnfocado: Bool

    private var nombreLimpio: String { nombre.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ej.: Mascotas", text: $nombre)
                        .focused($nombreEnfocado)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityLabel("Nombre de la categoría")
                } header: {
                    Text("Nombre")
                }

                Section {
                    HStack {
                        Text("Tope mensual")
                        Spacer(minLength: Espacio.xs)
                        CampoPlata(texto: $monto, alineacion: .trailing, etiqueta: "Tope mensual")
                            .frame(maxWidth: 160)
                    }
                } footer: {
                    Text("Opcional. Lo puedes cambiar cuando quieras.")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Nueva categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Agregar") { agregar() }
                        .fontWeight(.semibold)
                        .disabled(nombreLimpio.isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { nombreEnfocado = true }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func agregar() {
        guard !nombreLimpio.isEmpty else { return }
        store.agregarCategoria(nombre: nombreLimpio, mensual: Fmt.leerPlata(monto) ?? 0)
        cerrar()
    }
}

// MARK: - Hoja: nuevo gasto fijo o suscripción

private struct HojaNuevoFijo: View {
    let suscripcion: Bool

    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var cerrar

    @State private var nombre = ""
    @State private var monto = ""
    @State private var enDolares = false
    @State private var dia: Int?
    @FocusState private var nombreEnfocado: Bool

    private var nombreLimpio: String { nombre.trimmingCharacters(in: .whitespaces) }
    private var usarDolares: Bool { suscripcion && enDolares }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(suscripcion ? "Ej.: Netflix" : "Ej.: Arriendo", text: $nombre)
                        .focused($nombreEnfocado)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityLabel("Nombre")
                } header: {
                    Text("Nombre")
                }

                Section {
                    if suscripcion {
                        Toggle("Cobra en dólares", isOn: $enDolares)
                    }
                    HStack(spacing: Espacio.xs) {
                        Text(usarDolares ? "Valor en dólares" : "Valor mensual")
                        Spacer(minLength: Espacio.xs)
                        if usarDolares {
                            Text("USD")
                                .foregroundStyle(Theme.gris)
                                .accessibilityHidden(true)
                            TextField("0", text: $monto)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(.body, design: .rounded).weight(.medium))
                                .monospacedDigit()
                                .frame(maxWidth: 120)
                                .accessibilityLabel("Valor en dólares")
                        } else {
                            CampoPlata(texto: $monto, alineacion: .trailing, etiqueta: "Valor mensual en pesos")
                                .frame(maxWidth: 160)
                        }
                    }
                    Picker(suscripcion ? "Día de cobro" : "Día de pago", selection: $dia) {
                        Text("Sin día").tag(Int?.none)
                        ForEach(1...31, id: \.self) { numero in
                            Text("\(numero)").tag(Int?.some(numero))
                        }
                    }
                } footer: {
                    Text(usarDolares
                         ? "Se pasa a pesos con la TRM de \(Fmt.plata(store.data.trm))."
                         : "Si cambia cada mes, déjalo vacío: te preguntamos cuánto pagaste cuando marques «Ya pagué».")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(suscripcion ? "Nueva suscripción" : "Nuevo gasto fijo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Agregar") { agregar() }
                        .fontWeight(.semibold)
                        .disabled(nombreLimpio.isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { nombreEnfocado = true }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func agregar() {
        guard !nombreLimpio.isEmpty else { return }
        let valor = Fmt.leerPlata(monto)
        store.agregarFijo(
            nombre: nombreLimpio,
            monto: usarDolares ? nil : valor,
            usd: usarDolares ? valor : nil,
            dia: dia,
            suscripcion: suscripcion
        )
        cerrar()
    }
}
