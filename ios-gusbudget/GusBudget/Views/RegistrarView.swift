import SwiftUI

/// Registrar un gasto o un ingreso extra en 3 pasos (sección 2.1.3).
struct RegistrarView: View {
    @EnvironmentObject private var store: FinanceStore

    enum Tipo: String, CaseIterable, Identifiable {
        case gasto, ingreso
        var id: String { rawValue }
        var titulo: String { self == .gasto ? "Gasto" : "Ingreso extra" }
        var color: Color { self == .gasto ? Theme.acento : Theme.verde }
    }

    var tipoInicial: Tipo = .gasto
    var alTerminar: (() -> Void)? = nil

    @State private var tipo: Tipo = .gasto
    @State private var paso = 1
    @State private var texto = ""
    @State private var categoriaID: String?
    @State private var metodo: MetodoPago = .debito
    @State private var fuente: String?
    @State private var nota = ""
    @State private var fecha = Date()

    private let columnas = [GridItem(.adaptive(minimum: 94), spacing: 9)]
    private var monto: Decimal? { Fmt.leerPlata(texto) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            encabezado

            switch paso {
            case 1: pasoValor
            case 2: pasoDestino
            default: pasoResumen
            }
        }
        .panel()
        .animation(.easeInOut(duration: 0.2), value: paso)
        .animation(.easeInOut(duration: 0.2), value: tipo)
        .onAppear { tipo = tipoInicial }
    }

    // MARK: Encabezado

    private var encabezado: some View {
        VStack(spacing: 12) {
            Picker("Tipo", selection: $tipo) {
                ForEach(Tipo.allCases) { opcion in
                    Text(opcion.titulo).tag(opcion)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: tipo) { _ in reiniciar() }

            HStack(spacing: 6) {
                ForEach(1...3, id: \.self) { numero in
                    Capsule()
                        .fill(numero <= paso ? tipo.color : Theme.linea)
                        .frame(height: 4)
                }
            }
        }
    }

    // MARK: Paso 1 · valor

    private var pasoValor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tipo == .gasto ? "¿Cuánto gastaste?" : "¿Cuánto entró?")
                .font(.headline)
                .foregroundStyle(Theme.texto)

            CampoPlata(texto: $texto, grande: true)

            Button {
                paso = 2
            } label: {
                Text("Siguiente")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(tipo.color)
            .disabled(monto == nil || (monto ?? 0) <= 0)

            if tipo == .gasto {
                sugerencias
            }
        }
    }

    @ViewBuilder
    private var sugerencias: some View {
        let resultado = store.sugerencias()
        if !resultado.lista.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(resultado.porHora ? "A esta hora sueles comprar" : "Lo que más repites")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.gris)

                ForEach(resultado.lista) { habito in
                    Button {
                        usar(habito)
                    } label: {
                        HStack(spacing: 10) {
                            IconoCuadro(
                                simbolo: store.categoria(habito.categoriaID).simbolo,
                                color: store.categoria(habito.categoriaID).color,
                                lado: 32
                            )
                            VStack(alignment: .leading, spacing: 1) {
                                Text(habito.titulo)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Theme.texto)
                                Text(habito.descripcion)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.gris)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(Theme.gris)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func usar(_ habito: Habito) {
        texto = Fmt.numero(habito.valorTipico)
        categoriaID = habito.categoriaID
        nota = habito.titulo
        metodo = habito.metodo
        paso = 3
        Haptics.tap()
    }

    // MARK: Paso 2 · categoría o fuente

    private var pasoDestino: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tipo == .gasto ? "¿En qué lo gastaste?" : "¿De dónde vino esta plata?")
                    .font(.headline)
                    .foregroundStyle(Theme.texto)
                Spacer()
                Button("Volver") { paso = 1 }
                    .font(.caption)
            }

            if tipo == .gasto {
                LazyVGrid(columns: columnas, spacing: 9) {
                    ForEach(store.categoriasVisibles) { categoria in
                        Button {
                            categoriaID = categoria.id
                            paso = 3
                            Haptics.tap()
                        } label: {
                            VStack(spacing: 6) {
                                IconoCuadro(simbolo: categoria.simbolo, color: categoria.color, lado: 34)
                                Text(categoria.nombre)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.texto)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 78)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(Theme.fondo)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                LazyVGrid(columns: columnas, spacing: 9) {
                    ForEach(Semilla.fuentesExtra, id: \.self) { opcion in
                        Button {
                            fuente = opcion
                            paso = 3
                            Haptics.tap()
                        } label: {
                            Text(opcion)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.texto)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .fill(Theme.fondo)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: Paso 3 · resumen

    private var pasoResumen: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Fmt.plata(monto ?? 0))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.texto)
                    Text(tipo == .gasto
                         ? store.categoria(categoriaID ?? "otros").nombre
                         : (fuente ?? "Ingreso extra"))
                        .font(.caption)
                        .foregroundStyle(Theme.gris)
                }
                Spacer()
                Button("Cambiar") { paso = 1 }
                    .font(.caption)
            }

            if tipo == .gasto {
                VStack(alignment: .leading, spacing: 8) {
                    Text("¿Cómo pagaste?")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.gris)
                    Picker("Método", selection: $metodo) {
                        ForEach(MetodoPago.allCases) { opcion in
                            Text(opcion.titulo).tag(opcion)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            TextField(tipo == .gasto ? "Nota (opcional)" : "¿Qué fue? (opcional)", text: $nota)
                .textFieldStyle(.roundedBorder)

            DatePicker("Fecha", selection: $fecha, displayedComponents: .date)
                .environment(\.locale, Fmt.locale)
                .font(.subheadline)

            HStack(spacing: 10) {
                Button("Volver") { paso = 2 }
                    .font(.subheadline)
                    .buttonStyle(.bordered)

                Button {
                    guardar()
                } label: {
                    Text(tipo == .gasto ? "Guardar gasto" : "Guardar ingreso")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(tipo.color)
                .disabled(!puedeGuardar)
            }
        }
    }

    private var puedeGuardar: Bool {
        guard let monto, monto > 0 else { return false }
        return tipo == .gasto ? categoriaID != nil : fuente != nil
    }

    // MARK: Guardar

    private func guardar() {
        guard let monto, monto > 0 else { return }

        if tipo == .gasto, let categoriaID {
            store.agregarGasto(monto: monto, cat: categoriaID, metodo: metodo, nota: nota, fecha: fecha)
        } else if tipo == .ingreso, let fuente {
            store.agregarIngresoExtra(monto: monto, fuente: fuente, nota: nota, fecha: fecha)
        }
        reiniciar()
        alTerminar?()
    }

    private func reiniciar() {
        paso = 1
        texto = ""
        categoriaID = nil
        fuente = nil
        nota = ""
        metodo = .debito
        fecha = Date()
    }
}
