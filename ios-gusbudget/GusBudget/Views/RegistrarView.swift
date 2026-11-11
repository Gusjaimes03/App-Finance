import SwiftUI
import UIKit

/// Registrar un gasto o un ingreso extra en 3 pasos (sección 2.1.3):
/// 1. Valor (cifra grande + "lo de siempre"), 2. Categoría u origen, 3. Confirmar.
/// Vive dentro de `HojaRegistrar` (el botón "+"), que se cierra sola al guardar.
struct RegistrarView: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.ofrecerDeshacer) private var ofrecerDeshacer
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    /// Lo pone `HojaRegistrar`; si existe, la hoja se cierra sola al guardar.
    @Environment(\.alTerminarRegistro) private var alTerminarRegistro

    enum Tipo: String, CaseIterable, Identifiable {
        case gasto, ingreso
        var id: String { rawValue }
        var titulo: String { self == .gasto ? "Gasto" : "Ingreso" }
        var simbolo: String { self == .gasto ? "minus.circle.fill" : "plus.circle.fill" }
        var color: Color { self == .gasto ? Theme.acento : Theme.verde }
    }

    @State private var tipo: Tipo = .gasto
    @State private var paso = 1
    @State private var texto = ""
    @State private var categoriaID: String?
    @State private var metodo: MetodoPago = .debito
    @State private var fuente: String?
    @State private var nota = ""
    @State private var fecha = Date()
    /// Dirección de la transición entre pasos.
    @State private var adelante = true
    @FocusState private var notaEnfocada: Bool

    private let columnas = [GridItem(.adaptive(minimum: 92), spacing: 10)]
    private var monto: Decimal? { Fmt.leerPlata(texto) }
    private var montoValido: Bool { (monto ?? 0) > 0 }

    private var animacion: Animation? {
        reducirMovimiento ? nil : .spring(response: 0.35, dampingFraction: 0.85)
    }

    private var nombresPasos: [String] {
        ["Valor", tipo == .gasto ? "Categoría" : "Origen", "Confirmar"]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.l) {
            selectorTipo
            indicadorPasos

            ZStack(alignment: .topLeading) {
                Group {
                    switch paso {
                    case 1: pasoValor
                    case 2: pasoDestino
                    default: pasoResumen
                    }
                }
                .id(paso)
                .transition(transicion)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .toolbar {
            // En el paso 1 el único "Siguiente" es el botón grande bajo el valor.
            ToolbarItemGroup(placement: .keyboard) {
                if paso != 1 {
                    Spacer()
                    Button("Listo") { ocultarTeclado() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var transicion: AnyTransition {
        if reducirMovimiento { return .opacity }
        return .asymmetric(
            insertion: .move(edge: adelante ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: adelante ? .leading : .trailing).combined(with: .opacity)
        )
    }

    // MARK: Encabezado

    /// Gasto / Ingreso. Cambiar de tipo conserva el valor y la nota; solo se vuelve a elegir el destino.
    private var selectorTipo: some View {
        HStack(spacing: 4) {
            ForEach(Tipo.allCases) { opcion in
                let elegido = tipo == opcion
                Button {
                    cambiarTipo(a: opcion)
                } label: {
                    Label(opcion.titulo, systemImage: opcion.simbolo)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(elegido ? Theme.sobreAcento : Theme.gris)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Capsule(style: .continuous).fill(elegido ? opcion.color : Color.clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.presionable)
                .accessibilityLabel(opcion.titulo)
                .accessibilityAddTraits(elegido ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule(style: .continuous).fill(Theme.hundido))
        .animation(animacion, value: tipo)
    }

    private var indicadorPasos: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(0..<3, id: \.self) { indice in
                let numero = indice + 1
                VStack(alignment: .leading, spacing: 6) {
                    Capsule()
                        .fill(numero <= paso ? tipo.color : Theme.pista)
                        .frame(height: 4)
                    Text(nombresPasos[indice])
                        .font(numero == paso ? Font.caption.weight(.semibold) : Font.caption)
                        .foregroundStyle(numero == paso ? Theme.texto : Theme.gris)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .animation(animacion, value: paso)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Paso \(paso) de 3: \(nombresPasos[min(max(paso, 1), 3) - 1])")
    }

    private func botonAtras(a destino: Int) -> some View {
        Button {
            ir(a: destino)
        } label: {
            Label("Atrás", systemImage: "chevron.left")
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.acento)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.presionable)
        .accessibilityLabel("Volver al paso \(destino)")
    }

    // MARK: Paso 1 · valor

    private var pasoValor: some View {
        VStack(alignment: .leading, spacing: Espacio.l) {
            VStack(spacing: Espacio.xs) {
                Text(tipo == .gasto ? "¿Cuánto gastaste?" : "¿Cuánto entró?")
                    .font(.headline)
                    .foregroundStyle(Theme.gris)
                CampoPlata(texto: $texto, grande: true, alineacion: .center,
                           etiqueta: tipo == .gasto ? "Valor del gasto" : "Valor del ingreso",
                           enfocarAlAparecer: true)
                    .padding(.horizontal, Espacio.m)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Espacio.xl)
            .background(FondoTarjeta())

            if tipo == .gasto {
                sugerencias
            }

            Button("Siguiente") { ir(a: 2) }
                .buttonStyle(EstiloBotonPrincipal(color: tipo.color, colorTexto: Theme.sobreAcento))
                .disabled(!montoValido)
        }
    }

    @ViewBuilder
    private var sugerencias: some View {
        let resultado = store.sugerencias()
        if !resultado.lista.isEmpty {
            VStack(alignment: .leading, spacing: Espacio.titulo) {
                Sobrelinea(texto: resultado.porHora ? "A esta hora sueles comprar" : "Lo que más repites")

                VStack(spacing: 0) {
                    ForEach(Array(resultado.lista.enumerated()), id: \.element.id) { indice, habito in
                        if indice > 0 { SeparadorFila(sangria: 64) }
                        filaHabito(habito)
                    }
                }
                .panel(padding: 0)
            }
        }
    }

    private func filaHabito(_ habito: Habito) -> some View {
        let categoria = store.categoria(habito.categoriaID)
        return Button {
            usar(habito)
        } label: {
            HStack(spacing: Espacio.s) {
                IconoCuadro(simbolo: categoria.simbolo, color: categoria.color, lado: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(habito.titulo)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.texto)
                    Text(habito.descripcion)
                        .font(.footnote)
                        .foregroundStyle(Theme.gris)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.up.forward.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.acento)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Espacio.m)
            .padding(.vertical, Espacio.s)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.presionable)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Llena el valor y la categoría de una vez")
    }

    private func usar(_ habito: Habito) {
        texto = Fmt.numero(habito.valorTipico)
        categoriaID = habito.categoriaID
        nota = habito.titulo
        metodo = habito.metodo
        Haptics.tap()
        ir(a: 3)
    }

    // MARK: Paso 2 · categoría u origen

    private var pasoDestino: some View {
        VStack(alignment: .leading, spacing: Espacio.m) {
            HStack(spacing: Espacio.xs) {
                botonAtras(a: 1)
                    .padding(.leading, -Espacio.xxs)
                Spacer(minLength: Espacio.xs)
                Button {
                    ir(a: 1)
                } label: {
                    CifraPlata(valor: monto ?? 0, estilo: .media,
                               signo: tipo == .gasto ? .ninguno : .entrada)
                        .padding(.horizontal, Espacio.s)
                        .frame(minHeight: 36)
                        .background(Capsule(style: .continuous).fill(Theme.hundido))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.presionable)
                .accessibilityLabel("Valor: \(CifraPlata.textoAccesible(monto ?? 0, signo: .ninguno))")
                .accessibilityHint("Toca para cambiarlo")
            }

            Text(tipo == .gasto ? "¿En qué lo gastaste?" : "¿De dónde vino esta plata?")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.texto)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: columnas, spacing: 10) {
                if tipo == .gasto {
                    ForEach(store.categoriasVisibles) { categoria in
                        MosaicoCategoria(simbolo: categoria.simbolo, color: categoria.color,
                                         nombre: categoria.nombre,
                                         seleccionado: categoria.id == categoriaID) {
                            categoriaID = categoria.id
                            avanzarConPausa()
                        }
                    }
                } else {
                    ForEach(Semilla.fuentesExtra, id: \.self) { opcion in
                        MosaicoCategoria(simbolo: RegistrarView.simbolo(deFuente: opcion), color: Theme.verde,
                                         nombre: opcion, seleccionado: opcion == fuente) {
                            fuente = opcion
                            avanzarConPausa()
                        }
                    }
                }
            }
        }
    }

    /// Deja ver la selección un instante antes de pasar al resumen.
    private func avanzarConPausa() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if paso == 2 { ir(a: 3) }
        }
    }

    static func simbolo(deFuente fuente: String) -> String {
        switch fuente {
        case "Clase particular": return "graduationcap.fill"
        case "Venta": return "tag.fill"
        case "Regalo": return "gift.fill"
        case "Reembolso": return "arrow.uturn.backward.circle.fill"
        case "Trabajo extra": return "briefcase.fill"
        default: return "plus.circle.fill"
        }
    }

    // MARK: Paso 3 · confirmar

    private var nombreDestino: String {
        tipo == .gasto
            ? store.categoria(categoriaID ?? "otros").nombre
            : (fuente ?? "Ingreso extra")
    }

    private var pasoResumen: some View {
        VStack(alignment: .leading, spacing: Espacio.l) {
            botonAtras(a: 2)
                .padding(.leading, -Espacio.xxs)
                .padding(.bottom, -Espacio.s)

            tarjetaResumen

            if tipo == .gasto {
                VStack(alignment: .leading, spacing: Espacio.titulo) {
                    Sobrelinea(texto: "¿Cómo pagaste?")
                    selectorMetodo
                    if metodo == .credito {
                        Text("Se suma a lo que debes en la \(MetodoPago.credito.titulo).")
                            .font(.footnote)
                            .foregroundStyle(Theme.gris)
                            .padding(.horizontal, Espacio.xxs)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            VStack(alignment: .leading, spacing: Espacio.titulo) {
                Sobrelinea(texto: "Detalles")
                VStack(spacing: 0) {
                    HStack(spacing: Espacio.s) {
                        Image(systemName: "text.alignleft")
                            .font(.body)
                            .foregroundStyle(Theme.gris)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        TextField(tipo == .gasto ? "¿Qué fue? Ej.: almuerzo (opcional)" : "¿Qué fue? (opcional)",
                                  text: $nota)
                            .font(.body)
                            .focused($notaEnfocada)
                            .submitLabel(.done)
                            .onSubmit { notaEnfocada = false }
                            .accessibilityLabel("Nota")
                    }
                    .padding(.horizontal, Espacio.m)
                    .frame(minHeight: 52)

                    SeparadorFila(sangria: 52)

                    filaFecha
                        .padding(.horizontal, Espacio.m)
                        .padding(.vertical, Espacio.xs)
                }
                .panel(padding: 0)
            }

            Button(tipo == .gasto ? "Guardar gasto" : "Guardar ingreso") { guardar() }
                .buttonStyle(EstiloBotonPrincipal(color: tipo.color, colorTexto: Theme.sobreAcento))
                .disabled(!puedeGuardar)
        }
    }

    /// Valor y destino; cada uno se toca para corregirlo.
    private var tarjetaResumen: some View {
        VStack(spacing: 0) {
            Button {
                ir(a: 1)
            } label: {
                VStack(spacing: Espacio.xxs) {
                    Text(tipo == .gasto ? "Gasto" : "Ingreso extra")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.gris)
                    CifraPlata(valor: monto ?? 0, estilo: .hero,
                               signo: tipo == .gasto ? .ninguno : .entrada)
                    Label("Cambiar valor", systemImage: "pencil")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.acento)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Espacio.l)
                .padding(.horizontal, Espacio.m)
                .contentShape(Rectangle())
            }
            .buttonStyle(.presionable)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(tipo == .gasto ? "Gasto" : "Ingreso extra") de \(CifraPlata.textoAccesible(monto ?? 0, signo: .ninguno))")
            .accessibilityHint("Toca para cambiar el valor")
            .accessibilityAddTraits(.isButton)

            SeparadorFila(sangria: Espacio.m)

            Button {
                ir(a: 2)
            } label: {
                HStack(spacing: Espacio.s) {
                    if tipo == .gasto {
                        let categoria = store.categoria(categoriaID ?? "otros")
                        IconoCuadro(simbolo: categoria.simbolo, color: categoria.color, lado: 40)
                    } else {
                        IconoCuadro(simbolo: RegistrarView.simbolo(deFuente: fuente ?? ""), color: Theme.verde, lado: 40)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tipo == .gasto ? "Categoría" : "De dónde vino")
                            .font(.footnote)
                            .foregroundStyle(Theme.gris)
                        Text(nombreDestino)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.texto)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Cambiar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.acento)
                }
                .padding(.horizontal, Espacio.m)
                .padding(.vertical, Espacio.s)
                .frame(minHeight: 64)
                .contentShape(Rectangle())
            }
            .buttonStyle(.presionable)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(tipo == .gasto ? "Categoría" : "De dónde vino"): \(nombreDestino)")
            .accessibilityHint("Toca para cambiarla")
            .accessibilityAddTraits(.isButton)
        }
        .panel(padding: 0)
    }

    private var selectorMetodo: some View {
        HStack(spacing: Espacio.xs) {
            ForEach(MetodoPago.allCases) { opcion in
                let elegido = metodo == opcion
                Button {
                    Haptics.seleccion()
                    metodo = opcion
                } label: {
                    HStack(spacing: Espacio.xs) {
                        Image(systemName: opcion.simbolo)
                            .font(.body.weight(.semibold))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(opcion.tituloCorto)
                                .font(.body.weight(elegido ? .semibold : .medium))
                            Text(opcion == .credito ? MetodoPago.credito.titulo : "o efectivo")
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
                .accessibilityLabel(opcion.titulo)
                .accessibilityAddTraits(elegido ? [.isButton, .isSelected] : .isButton)
            }
        }
        .animation(animacion, value: metodo)
    }

    private var esHoy: Bool { Calendar.app.isDateInToday(fecha) }
    private var esAyer: Bool { Calendar.app.isDateInYesterday(fecha) }

    /// "Hoy" y "Ayer" a un toque; el calendario para cualquier otro día.
    private var filaFecha: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Espacio.xs) {
                iconoFecha
                atajosFecha
                Spacer(minLength: Espacio.xs)
                selectorFecha
            }
            VStack(alignment: .leading, spacing: Espacio.xs) {
                HStack(spacing: Espacio.xs) {
                    iconoFecha
                    atajosFecha
                }
                selectorFecha
            }
        }
        .frame(minHeight: 44)
    }

    private var iconoFecha: some View {
        Image(systemName: "calendar")
            .font(.body)
            .foregroundStyle(Theme.gris)
            .frame(width: 24)
            .padding(.trailing, Espacio.xxs)
            .accessibilityHidden(true)
    }

    private var atajosFecha: some View {
        HStack(spacing: 6) {
            Chip(titulo: "Hoy", seleccionado: esHoy) { fecha = Date() }
            Chip(titulo: "Ayer", seleccionado: esAyer) { fecha = Date().sumandoDias(-1) }
        }
        .fixedSize()
    }

    private var selectorFecha: some View {
        DatePicker("Fecha", selection: $fecha, displayedComponents: .date)
            .datePickerStyle(.compact)
            .labelsHidden()
            .environment(\.locale, Fmt.locale)
            .accessibilityLabel("Fecha")
    }

    private var puedeGuardar: Bool {
        guard let monto, monto > 0 else { return false }
        return tipo == .gasto ? categoriaID != nil : fuente != nil
    }

    // MARK: Navegación entre pasos

    private func ir(a nuevo: Int) {
        guard nuevo != paso else { return }
        adelante = nuevo > paso
        if nuevo != 3 { notaEnfocada = false }
        // Se espera una vuelta para que la vista que sale ya tenga la dirección nueva.
        DispatchQueue.main.async {
            withAnimation(animacion) { paso = nuevo }
        }
    }

    private func cambiarTipo(a nuevo: Tipo) {
        guard nuevo != tipo else { return }
        Haptics.seleccion()
        tipo = nuevo
        categoriaID = nil
        fuente = nil
        metodo = .debito
        if paso == 3 { ir(a: 2) }
    }

    private func ocultarTeclado() {
        notaEnfocada = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: Guardar

    private func guardar() {
        guard let monto, monto > 0 else { return }
        var deshacer: (() -> Void)?
        let tienda = store

        if tipo == .gasto, let categoriaID {
            store.agregarGasto(monto: monto, cat: categoriaID, metodo: metodo, nota: nota, fecha: fecha)
            if let nuevo = tienda.data.gastos.last {
                deshacer = { tienda.borrarGasto(nuevo) }
            }
        } else if tipo == .ingreso, let fuente {
            store.agregarIngresoExtra(monto: monto, fuente: fuente, nota: nota, fecha: fecha)
            if let nuevo = tienda.data.agenda.last {
                deshacer = { tienda.quitarAgenda(nuevo) }
            }
        }
        if let deshacer {
            ofrecerDeshacer(nil, deshacer: deshacer)
        }
        // Dentro de la hoja no se reinicia: se está cerrando y volver al paso 1
        // abriría el teclado durante la animación. Incrustado, queda listo para otro.
        if alTerminarRegistro == nil {
            reiniciar()
        }
    }

    private func reiniciar() {
        adelante = false
        paso = 1
        texto = ""
        categoriaID = nil
        fuente = nil
        nota = ""
        metodo = .debito
        fecha = Date()
    }
}
