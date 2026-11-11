import SwiftUI
import UniformTypeIdentifiers

/// Ajustes: Form nativo agrupado al estilo de la app Ajustes de iOS.
/// Orden: estado de la app · Privacidad · Respaldo y datos · Firma de 7 días · Avanzado · Borrar todo · Acerca de.
struct AjustesView: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var cerrar

    @State private var archivo: ArchivoCompartido?
    @State private var importando = false
    @State private var confirmarRestaurar = false
    @State private var confirmarBorrado = false
    @State private var mensaje: Mensaje?

    private struct Mensaje: Identifiable {
        let id = UUID()
        let titulo: String
        let texto: String
    }

    private var diasRestantes: Int? {
        RenewalReminder.daysRemaining(signedOn: store.data.ajustes.ultimaFirma)
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let corta = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(corta) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                seccionEstado
                seccionBloqueo
                seccionDatos
                seccionFirma
                seccionPruebas
                seccionBorrar
                seccionAcerca
            }
            .scrollContentBackground(.hidden)
            .fondoPantalla()
            .tint(Theme.acento)
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { cerrar() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(item: $archivo) { elemento in
                HojaCompartir(elementos: [elemento.url])
            }
            .fileImporter(isPresented: $importando, allowedContentTypes: [.json]) { resultado in
                switch resultado {
                case .success(let url):
                    do {
                        try store.importarRespaldo(url)
                        Haptics.success()
                        mensaje = Mensaje(titulo: "Listo", texto: "Se restauró el respaldo.")
                    } catch {
                        mensaje = Mensaje(titulo: "No se pudo abrir", texto: "Elige un respaldo .json hecho por esta app.")
                    }
                case .failure(let error):
                    mensaje = Mensaje(titulo: "No se pudo abrir", texto: error.localizedDescription)
                }
            }
            .alert(item: $mensaje) { aviso in
                Alert(title: Text(aviso.titulo), message: Text(aviso.texto), dismissButton: .default(Text("Entendido")))
            }
        }
    }

    // MARK: Estado de la app (tarjeta de arriba)

    private var seccionEstado: some View {
        Section {
            Group {
                HStack(spacing: Espacio.m) {
                    LogoApp()
                    VStack(alignment: .leading, spacing: Espacio.xxs) {
                        Text("Mi plata")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.texto)
                        Text("Tus números, solo en este iPhone")
                            .font(.subheadline)
                            .foregroundStyle(Theme.gris)
                            .fixedSize(horizontal: false, vertical: true)
                        Insignia(texto: estadoFirma.texto, tono: estadoFirma.tono, simbolo: estadoFirma.simbolo)
                            .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, Espacio.xs)
                .accessibilityElement(children: .combine)
            }
            .filaAjuste()
        } footer: {
            if let dias = diasRestantes, dias <= 1 {
                Text("Reinstálala desde el Mac para que siga abriendo. Tus datos se conservan mientras no borres la app.")
            }
        }
    }

    private struct EstadoFirma {
        let texto: String
        let tono: Tono
        let simbolo: String
    }

    private var estadoFirma: EstadoFirma {
        guard let dias = diasRestantes else {
            return EstadoFirma(texto: "Sin fecha de instalación", tono: .neutro, simbolo: "questionmark.circle")
        }
        if dias < 0 { return EstadoFirma(texto: "Caducada", tono: .negativo, simbolo: "xmark.octagon.fill") }
        if dias == 0 { return EstadoFirma(texto: "Caduca hoy", tono: .negativo, simbolo: "exclamationmark.triangle.fill") }
        if dias == 1 { return EstadoFirma(texto: "Caduca mañana", tono: .aviso, simbolo: "exclamationmark.triangle.fill") }
        return EstadoFirma(texto: "Funciona \(dias) días más", tono: .positivo, simbolo: "checkmark.circle.fill")
    }

    // MARK: Privacidad

    private var seccionBloqueo: some View {
        Section {
            Group {
                Toggle(isOn: Binding(
                    get: { store.data.ajustes.bloqueoActivo },
                    set: { activo in
                        var ajustes = store.data.ajustes
                        ajustes.bloqueoActivo = activo
                        store.actualizarAjustes(ajustes)
                    }
                )) {
                    EtiquetaAjuste(
                        titulo: "Pedir \(AppLock.methodName) al abrir",
                        simbolo: AppLock.methodName == "Touch ID" ? "touchid" : (AppLock.methodName == "Face ID" ? "faceid" : "lock.fill"),
                        color: ColorAjuste.verde
                    )
                }
                .disabled(!AppLock.isAvailable)
            }
            .filaAjuste()
        } header: {
            Text("Privacidad")
        } footer: {
            Text(AppLock.isAvailable
                 ? "Tus números quedan tapados hasta que te identifiques."
                 : "Este iPhone no tiene código ni biometría configurados.")
        }
    }

    // MARK: Respaldo y datos

    private var seccionDatos: some View {
        Section {
            Group {
                Button {
                    hacer { try store.exportarRespaldo() }
                } label: {
                    EtiquetaAjuste(titulo: "Guardar respaldo", simbolo: "externaldrive.fill", color: ColorAjuste.azul) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.grisClaro)
                    }
                }
                .accessibilityHint("Crea un archivo .json para guardarlo o compartirlo")

                Button {
                    Haptics.warning()
                    confirmarRestaurar = true
                } label: {
                    EtiquetaAjuste(titulo: "Restaurar un respaldo", simbolo: "clock.arrow.circlepath", color: ColorAjuste.indigo)
                }
                .confirmationDialog("¿Restaurar un respaldo?", isPresented: $confirmarRestaurar, titleVisibility: .visible) {
                    Button("Elegir archivo") { abrirImportador() }
                    Button("Cancelar", role: .cancel) {}
                } message: {
                    Text("Lo que tienes ahora se reemplaza por lo del archivo. Si quieres conservarlo, guarda un respaldo primero.")
                }

                Button {
                    hacer { try store.exportarCSV() }
                } label: {
                    EtiquetaAjuste(titulo: "Exportar a Excel (CSV)", simbolo: "tablecells.fill", color: ColorAjuste.verdeHoja) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.grisClaro)
                    }
                }
                .accessibilityHint("Crea una tabla con tus movimientos")
            }
            .filaAjuste()
        } header: {
            Text("Respaldo y datos")
        } footer: {
            Text("Todo se guarda solo en este iPhone. Antes de reinstalar la app conviene guardar un respaldo.")
        }
    }

    private func hacer(_ accion: () throws -> URL) {
        do {
            archivo = ArchivoCompartido(url: try accion())
        } catch {
            mensaje = Mensaje(titulo: "No se pudo exportar", texto: error.localizedDescription)
        }
    }

    /// Abre el selector de archivos cuando el diálogo de confirmación ya se cerró.
    private func abrirImportador() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            importando = true
        }
    }

    // MARK: Firma de 7 días

    private var seccionFirma: some View {
        Section {
            Group {
                LabeledContent {
                    Text(store.data.ajustes.ultimaFirma.map { Fmt.fechaCorta($0) } ?? "Sin registrar")
                        .foregroundStyle(Theme.gris)
                } label: {
                    EtiquetaAjuste(titulo: "Instalada el", simbolo: "iphone", color: ColorAjuste.gris)
                }

                if let dias = diasRestantes {
                    LabeledContent {
                        Text(textoCaduca(dias))
                            .fontWeight(dias <= 1 ? .semibold : .regular)
                            .foregroundStyle(dias <= 1 ? Theme.rojo : Theme.gris)
                    } label: {
                        EtiquetaAjuste(titulo: "Caduca", simbolo: "hourglass", color: dias <= 1 ? ColorAjuste.rojo : ColorAjuste.naranja)
                    }
                }

                Toggle(isOn: enlaceRecordatorio) {
                    EtiquetaAjuste(titulo: "Avisarme 1 día antes", simbolo: "bell.badge.fill", color: ColorAjuste.rojo)
                }

                Button {
                    var ajustes = store.data.ajustes
                    ajustes.ultimaFirma = Date()
                    store.actualizarAjustes(ajustes)
                    Haptics.success()
                    Task { @MainActor in await reprogramar() }
                } label: {
                    Label("La reinstalé hoy", systemImage: "arrow.clockwise")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.acento)
                }
                .accessibilityHint("Vuelve a contar los \(RenewalReminder.validityDays) días desde hoy")
            }
            .filaAjuste()
        } header: {
            Text("Firma de \(RenewalReminder.validityDays) días")
        } footer: {
            Text("Con un Apple ID gratis la app funciona \(RenewalReminder.validityDays) días. Al reinstalarla desde Xcode tus datos se conservan mientras no borres la app del iPhone.")
        }
    }

    private func textoCaduca(_ dias: Int) -> String {
        if dias < 0 { return "Caducada" }
        if dias == 0 { return "Hoy" }
        if dias == 1 { return "Mañana" }
        return "En \(dias) días"
    }

    private var enlaceRecordatorio: Binding<Bool> {
        Binding(
            get: { store.data.ajustes.recordatorioFirma },
            set: { activo in
                var ajustes = store.data.ajustes
                ajustes.recordatorioFirma = activo
                if activo && ajustes.ultimaFirma == nil { ajustes.ultimaFirma = Date() }
                store.actualizarAjustes(ajustes)

                Task { @MainActor in
                    if activo {
                        let permitido = await RenewalReminder.requestAuthorization()
                        if permitido {
                            await reprogramar()
                        } else {
                            var sinPermiso = store.data.ajustes
                            sinPermiso.recordatorioFirma = false
                            store.actualizarAjustes(sinPermiso)
                            mensaje = Mensaje(
                                titulo: "Notificaciones apagadas",
                                texto: "Actívalas en Ajustes de iOS › GusBudget › Notificaciones."
                            )
                        }
                    } else {
                        RenewalReminder.cancel()
                    }
                }
            }
        )
    }

    private func reprogramar() async {
        guard store.data.ajustes.recordatorioFirma,
              let firma = store.data.ajustes.ultimaFirma else { return }
        await RenewalReminder.schedule(signedOn: firma)
    }

    // MARK: Avanzado

    private var seccionPruebas: some View {
        Section {
            Group {
                NavigationLink {
                    AutopruebasView()
                } label: {
                    EtiquetaAjuste(titulo: "Revisar las cuentas", simbolo: "checkmark.seal.fill", color: ColorAjuste.morado)
                }
            }
            .filaAjuste()
        } header: {
            Text("Avanzado")
        } footer: {
            Text("Corre las pruebas de las cuentas con datos de mentira, sin tocar los tuyos.")
        }
    }

    // MARK: Borrar todo

    private var seccionBorrar: some View {
        Section {
            Group {
                Button(role: .destructive) {
                    Haptics.warning()
                    confirmarBorrado = true
                } label: {
                    HStack(spacing: Espacio.xs) {
                        Image(systemName: "trash")
                            .accessibilityHidden(true)
                        Text("Borrar todo y empezar de cero")
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.rojo)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .confirmationDialog("¿Borrar todo y empezar de cero?", isPresented: $confirmarBorrado, titleVisibility: .visible) {
                    Button("Borrar todo", role: .destructive) { store.empezarDeCero() }
                    Button("Cancelar", role: .cancel) {}
                } message: {
                    Text("Se borran gastos, pagos, cajitas y cobros. Las categorías y los fijos vuelven a los de fábrica.")
                }
            }
            .filaAjuste()
        } footer: {
            Text("No se puede deshacer. Guarda un respaldo antes si crees que lo vas a necesitar.")
        }
    }

    // MARK: Acerca de

    private var seccionAcerca: some View {
        Section {
            Group {
                LabeledContent {
                    Text("\(store.data.gastos.count)")
                        .monospacedDigit()
                        .foregroundStyle(Theme.gris)
                } label: {
                    EtiquetaAjuste(titulo: "Gastos registrados", simbolo: "list.number", color: ColorAjuste.azul)
                }
                LabeledContent {
                    Text(version)
                        .monospacedDigit()
                        .foregroundStyle(Theme.gris)
                } label: {
                    EtiquetaAjuste(titulo: "Versión", simbolo: "info", color: ColorAjuste.gris)
                }
            }
            .filaAjuste()
        } header: {
            Text("Acerca de Mi plata")
        } footer: {
            Text("Hecha para Gustavo. Sin cuentas, sin servidores, sin anuncios.")
        }
    }
}

// MARK: - Piezas privadas de Ajustes

/// Colores fijos de los íconos de Ajustes (glifo blanco encima, igual en claro y oscuro).
private enum ColorAjuste {
    static let azul = Color(hex: "2B48D8", adaptar: false)
    static let indigo = Color(hex: "1A2A6B", adaptar: false)
    static let verde = Color(hex: "16975A", adaptar: false)
    static let verdeHoja = Color(hex: "0F766E", adaptar: false)
    static let naranja = Color(hex: "D97706", adaptar: false)
    static let rojo = Color(hex: "D1342B", adaptar: false)
    static let morado = Color(hex: "6D28D9", adaptar: false)
    static let gris = Color(hex: "6B7391", adaptar: false)
}

/// Cuadro de color con glifo blanco, como en la app Ajustes de iOS.
private struct IconoAjuste: View {
    let simbolo: String
    let color: Color

    @ScaledMetric(relativeTo: .body) private var ladoBase: CGFloat = 30

    private var lado: CGFloat { min(ladoBase, 44) }

    var body: some View {
        Image(systemName: simbolo)
            .font(.system(size: lado * 0.5, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: lado, height: lado)
            .background(
                RoundedRectangle(cornerRadius: lado * 0.26, style: .continuous)
                    .fill(color)
            )
            .accessibilityHidden(true)
    }
}

/// Etiqueta de fila: ícono de color + título y, opcionalmente, algo a la derecha.
private struct EtiquetaAjuste<Derecha: View>: View {
    let titulo: String
    let simbolo: String
    let color: Color
    @ViewBuilder var derecha: () -> Derecha

    var body: some View {
        Label {
            if Derecha.self == EmptyView.self {
                textoTitulo
            } else {
                HStack(spacing: Espacio.xs) {
                    textoTitulo
                    Spacer(minLength: 0)
                    derecha()
                }
            }
        } icon: {
            IconoAjuste(simbolo: simbolo, color: color)
        }
        .padding(.vertical, 2)
    }

    private var textoTitulo: some View {
        Text(titulo)
            .foregroundStyle(Theme.texto)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension EtiquetaAjuste where Derecha == EmptyView {
    init(titulo: String, simbolo: String, color: Color) {
        self.init(titulo: titulo, simbolo: simbolo, color: color) { EmptyView() }
    }
}

/// Logo de la app: degradado de marca con el "$" en sol.
private struct LogoApp: View {
    @ScaledMetric(relativeTo: .title3) private var ladoBase: CGFloat = 60

    private var lado: CGFloat { min(ladoBase, 84) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: lado * 0.26, style: .continuous)
                .fill(Theme.heroGradient)
            Image(systemName: "dollarsign")
                .font(.system(size: lado * 0.5, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.sol)
        }
        .frame(width: lado, height: lado)
        .accessibilityHidden(true)
    }
}

private extension View {
    /// Fondo y separador de una fila de Ajustes con los colores de la app.
    func filaAjuste() -> some View {
        self
            .listRowBackground(Theme.superficie)
            .listRowSeparatorTint(Theme.linea)
    }
}

// MARK: - Autopruebas

/// Resultado de las pruebas mínimas de la especificación.
struct AutopruebasView: View {
    @State private var pruebas: [Autoprueba] = []

    private var pasan: Int { pruebas.filter(\.pasa).count }
    private var todasPasan: Bool { !pruebas.isEmpty && pasan == pruebas.count }
    private var avance: Double { pruebas.isEmpty ? 0 : Double(pasan) / Double(pruebas.count) }
    /// Las que fallan van primero.
    private var ordenadas: [Autoprueba] { pruebas.filter { !$0.pasa } + pruebas.filter(\.pasa) }

    var body: some View {
        List {
            Section {
                HStack(spacing: Espacio.m) {
                    AnilloProgreso(conPorcentaje: avance, color: todasPasan ? Theme.verde : Theme.rojo, lado: 64)
                    VStack(alignment: .leading, spacing: Espacio.xxs) {
                        Text(pruebas.isEmpty ? "Revisando…" : (todasPasan ? "Las cuentas cuadran" : "Algo no cuadra"))
                            .font(.headline)
                            .foregroundStyle(Theme.texto)
                        Text("\(pasan) de \(pruebas.count) pruebas pasan")
                            .font(.subheadline)
                            .foregroundStyle(Theme.gris)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, Espacio.xs)
                .accessibilityElement(children: .combine)
                .listRowBackground(Theme.superficie)
            } footer: {
                Text("Usan datos de mentira: tus datos no se tocan.")
            }

            Section {
                ForEach(ordenadas) { prueba in
                    HStack(alignment: .top, spacing: Espacio.s) {
                        Image(systemName: prueba.pasa ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(prueba.pasa ? Theme.verde : Theme.rojo)
                            .accessibilityLabel(prueba.pasa ? "Pasa" : "Falla")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prueba.nombre)
                                .font(.body.weight(.medium))
                                .foregroundStyle(Theme.texto)
                            Text(prueba.detalle)
                                .font(.footnote)
                                .foregroundStyle(Theme.gris)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, Espacio.xxs)
                    .accessibilityElement(children: .combine)
                    .listRowBackground(Theme.superficie)
                    .listRowSeparatorTint(Theme.linea)
                }
            } header: {
                Text("Pruebas")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .fondoPantalla()
        .navigationTitle("Revisar las cuentas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    correr()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Volver a revisar")
            }
        }
        .refreshable { correr() }
        .onAppear { pruebas = Autopruebas.correr() }
    }

    private func correr() {
        pruebas = Autopruebas.correr()
        Haptics.seleccion()
    }
}
