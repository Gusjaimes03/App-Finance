import SwiftUI

// MARK: - Acciones globales que pone RootView en el entorno

/// Abre la hoja de registro (la misma del botón flotante) desde cualquier pantalla.
///
///     @Environment(\.abrirRegistro) private var abrirRegistro
///     Button("Registra tu primer gasto") { abrirRegistro() }
struct AccionAbrirRegistro {
    var accion: () -> Void = {}
    func callAsFunction() { accion() }
}

/// Muestra el toast con un botón "Deshacer" durante unos segundos.
/// Llamarlo justo después de la acción del store (que ya pone su propio aviso).
///
///     @Environment(\.ofrecerDeshacer) private var ofrecerDeshacer
///     store.registrar(obligacion, monto: m, fecha: f)
///     ofrecerDeshacer { store.deshacerAgenda(...) }
///     // Si el store no pone aviso, pasa el texto: ofrecerDeshacer("Pago borrado") { ... }
struct AccionDeshacer {
    var accion: (String?, @escaping () -> Void) -> Void = { _, _ in }
    func callAsFunction(_ texto: String? = nil, deshacer: @escaping () -> Void) {
        accion(texto, deshacer)
    }
}

/// Cambia de pestaña desde una pantalla (por ejemplo, "Ver todos" en Inicio → Pagos).
///
///     @Environment(\.irAPestana) private var irAPestana
///     Button("Ver todos") { irAPestana(.pagos) }
struct AccionIrAPestana {
    var accion: (RootView.Pestana) -> Void = { _ in }
    func callAsFunction(_ pestana: RootView.Pestana) { accion(pestana) }
}

private struct ClaveAbrirRegistro: EnvironmentKey {
    static let defaultValue = AccionAbrirRegistro()
}

private struct ClaveDeshacer: EnvironmentKey {
    static let defaultValue = AccionDeshacer()
}

private struct ClaveIrAPestana: EnvironmentKey {
    static let defaultValue = AccionIrAPestana()
}

private struct ClaveTerminarRegistro: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var abrirRegistro: AccionAbrirRegistro {
        get { self[ClaveAbrirRegistro.self] }
        set { self[ClaveAbrirRegistro.self] = newValue }
    }

    var ofrecerDeshacer: AccionDeshacer {
        get { self[ClaveDeshacer.self] }
        set { self[ClaveDeshacer.self] = newValue }
    }

    var irAPestana: AccionIrAPestana {
        get { self[ClaveIrAPestana.self] }
        set { self[ClaveIrAPestana.self] = newValue }
    }

    /// Lo pone `HojaRegistrar`: `RegistrarView` puede llamarlo después de guardar para cerrar la hoja.
    /// Es nil cuando el registro está incrustado en una pantalla.
    var alTerminarRegistro: (() -> Void)? {
        get { self[ClaveTerminarRegistro.self] }
        set { self[ClaveTerminarRegistro.self] = newValue }
    }
}

// MARK: - Botón de ajustes

/// Agrega el engranaje de Ajustes a la barra de navegación y presenta la hoja.
/// Aplicarlo al contenido DENTRO del `NavigationStack`.
///
///     ScrollView { … }.navigationTitle("Pagos").conBotonAjustes()
struct BotonAjustesModifier: ViewModifier {
    @EnvironmentObject private var store: FinanceStore
    @State private var mostrar = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        mostrar = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel("Ajustes")
                }
            }
            .sheet(isPresented: $mostrar) {
                AjustesView().environmentObject(store)
            }
    }
}

extension View {
    func conBotonAjustes() -> some View {
        modifier(BotonAjustesModifier())
    }
}
