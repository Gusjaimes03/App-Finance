import SwiftUI
import UniformTypeIdentifiers

struct AjustesView: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var cerrar

    @State private var archivo: ArchivoCompartido?
    @State private var importando = false
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
                seccionFirma
                seccionBloqueo
                seccionDatos
                seccionPruebas
                seccionAcerca
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { cerrar() }
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
            .confirmationDialog("¿Borrar todo y empezar de cero?", isPresented: $confirmarBorrado, titleVisibility: .visible) {
                Button("Borrar todo", role: .destructive) { store.empezarDeCero() }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Se borran gastos, pagos, cajitas y cobros. Las categorías y los fijos vuelven a los de fábrica.")
            }
        }
    }

    // MARK: Firma de 7 días

    private var seccionFirma: some View {
        Section {
            HStack {
                Label("Instalada el", systemImage: "iphone.and.arrow.forward")
                Spacer()
                Text(store.data.ajustes.ultimaFirma.map { Fmt.fechaCorta($0) } ?? "Sin registrar")
                    .foregroundStyle(Theme.gris)
            }

            if let dias = diasRestantes {
                HStack {
                    Label("Caduca", systemImage: "clock")
                    Spacer()
                    Text(dias < 0 ? "Caducada" : (dias == 0 ? "Hoy" : "En \(dias) día(s)"))
                        .foregroundStyle(dias <= 1 ? Theme.rojo : Theme.gris)
                }
            }

            Button {
                var ajustes = store.data.ajustes
                ajustes.ultimaFirma = Date()
                store.actualizarAjustes(ajustes)
                Task { @MainActor in await reprogramar() }
            } label: {
                Label("Marcar como reinstalada hoy", systemImage: "arrow.clockwise")
            }

            Toggle(isOn: enlaceRecordatorio) {
                Label("Avisarme 1 día antes", systemImage: "bell.badge")
            }
        } header: {
            Text("Firma con Apple ID gratis")
        } footer: {
            Text("Una app firmada con Apple ID gratuito funciona \(RenewalReminder.validityDays) días. Al reinstalarla desde Xcode los datos se conservan mientras no borres la app del iPhone.")
        }
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

    // MARK: Bloqueo

    private var seccionBloqueo: some View {
        Section {
            Toggle(isOn: Binding(
                get: { store.data.ajustes.bloqueoActivo },
                set: { activo in
                    var ajustes = store.data.ajustes
                    ajustes.bloqueoActivo = activo
                    store.actualizarAjustes(ajustes)
                }
            )) {
                Label("Pedir \(AppLock.methodName) al abrir", systemImage: "lock.fill")
            }
            .disabled(!AppLock.isAvailable)
        } header: {
            Text("Privacidad")
        } footer: {
            Text(AppLock.isAvailable
                 ? "Tus números quedan tapados hasta que te identifiques."
                 : "Este iPhone no tiene código ni biometría configurados.")
        }
    }

    // MARK: Datos

    private var seccionDatos: some View {
        Section {
            Button {
                hacer { try store.exportarCSV() }
            } label: {
                Label("Exportar CSV", systemImage: "tablecells")
            }

            Button {
                hacer { try store.exportarRespaldo() }
            } label: {
                Label("Guardar respaldo (.json)", systemImage: "arrow.down.doc")
            }

            Button {
                importando = true
            } label: {
                Label("Restaurar respaldo", systemImage: "arrow.up.doc")
            }

            Button(role: .destructive) {
                confirmarBorrado = true
            } label: {
                Label("Borrar todo y empezar de cero", systemImage: "trash")
            }
        } header: {
            Text("Datos")
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

    // MARK: Autopruebas

    private var seccionPruebas: some View {
        Section {
            NavigationLink {
                AutopruebasView()
            } label: {
                Label("Revisar las cuentas", systemImage: "checkmark.seal")
            }
        } footer: {
            Text("Corre las pruebas de la especificación sobre datos de mentira, sin tocar los tuyos.")
        }
    }

    // MARK: Acerca de

    private var seccionAcerca: some View {
        Section {
            HStack {
                Text("Gastos registrados")
                Spacer()
                Text("\(store.data.gastos.count)").foregroundStyle(Theme.gris)
            }
            HStack {
                Text("Versión")
                Spacer()
                Text(version).foregroundStyle(Theme.gris)
            }
        } header: {
            Text("GusBudget · Mi plata")
        } footer: {
            Text("Hecha para Gustavo. Sin cuentas, sin servidores, sin anuncios.")
        }
    }
}

/// Resultado de las pruebas mínimas de la especificación.
struct AutopruebasView: View {
    @State private var pruebas: [Autoprueba] = []

    var body: some View {
        List {
            Section {
                ForEach(pruebas) { prueba in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: prueba.pasa ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(prueba.pasa ? Theme.verde : Theme.rojo)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prueba.nombre)
                                .font(.subheadline.weight(.medium))
                            Text(prueba.detalle)
                                .font(.caption2)
                                .foregroundStyle(Theme.gris)
                        }
                    }
                }
            } header: {
                Text("\(pruebas.filter(\.pasa).count) de \(pruebas.count) pasan")
            }
        }
        .navigationTitle("Revisar las cuentas")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { pruebas = Autopruebas.correr() }
    }
}
